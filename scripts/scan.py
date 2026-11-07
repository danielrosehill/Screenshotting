#!/usr/bin/env python3
"""
First-pass risk scan of a screenshot: find sensitive text and where it sits.

Usage:
  scan.py IMAGE [--overlay [PATH]] [--lang eng] [--reveal] [--min-conf 30]

Pipeline, all local, no ML models:
  1. Tesseract word boxes, on normal and inverted copies so that both light and
     dark UI areas are read.
  2. Pattern detectors over each OCR line: secrets, emails, phones, IPs, cards...
  3. gitleaks over the OCR text, when installed.
  4. Watchlist of the user's own terms, plus the pii-scanner inventory if present.
  5. exiftool metadata check, when installed.

Prints JSON. Finding text is masked unless --reveal is given. --overlay writes a
numbered review image, by default <dir>/flagged/<stem>_flagged.png; it shows the
sensitive content, so it is for review only. The input is never modified.

OCR misses things: an empty result does not mean the image is safe. This pass finds
patterns, not meaning. Names, medical terms and faces need a vision pass or the
watchlist.

Exit 0 = scan ran, whether or not anything was found. Exit 1 = could not run.
"""
from __future__ import annotations
import argparse, csv, io, json, math, os, re, shutil, subprocess, sys, tempfile
from collections import Counter
from pathlib import Path
from PIL import Image, ImageOps

ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}
COLORS = {"critical": "red", "high": "red", "medium": "orange", "low": "yellow"}


def entropy(s: str) -> float:
    return -sum(c / len(s) * math.log2(c / len(s)) for c in Counter(s).values())


def luhn(s: str) -> bool:
    d = [int(c) for c in re.sub(r"\D", "", s)][::-1]
    return 13 <= len(d) <= 19 and sum(x if i % 2 == 0 else sum(divmod(x * 2, 10)) for i, x in enumerate(d)) % 10 == 0


def iban_ok(s: str) -> bool:
    t = re.sub(r"\s", "", s).upper()
    return int("".join(str(int(c, 36)) for c in t[4:] + t[:4])) % 97 == 1


def private_ip(s: str) -> bool:
    return bool(re.match(r"(10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)", s))


def valid_ip(s: str) -> bool:
    return all(int(p) <= 255 for p in s.split("."))


def phone_ok(s: str) -> bool:
    return 9 <= len(re.sub(r"\D", "", s)) <= 15


def token_ok(s: str) -> bool:
    return entropy(s) >= 3.5 and bool(re.search(r"\d", s)) and bool(re.search(r"[A-Za-z]", s))


# (type, severity, regex, optional validator)
DETECTORS = [
    ("private-key", "critical", r"-----BEGIN [A-Z ]*PRIVATE KEY", None),
    ("jwt", "critical", r"\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{4,}", None),
    ("api-key", "critical", r"\b(?:sk-[\w-]{16,}|gh[pousr]_\w{20,}|github_pat_\w{20,}|glpat-[\w-]{16,}|xox[abprs]-[\w-]{10,}|AKIA[0-9A-Z]{12,}|AIza[\w-]{30,})", None),
    ("labelled-secret", "critical", r"(?i)\b(?:password|passwd|pwd|secret|api[_ -]?key|access[_ -]?token|auth[_ -]?token)\b\s*[:=]\s*\S+", None),
    ("url-credential", "critical", r"(?i)(?:\w+://[^\s/:]+:[^\s/@]+@\S+|[?&](?:token|key|secret|password|auth|api_key|sig)=[^\s&]+)", None),
    ("high-entropy-token", "high", r"(?<![\w/+-])[A-Za-z0-9_+/=-]{32,}", token_ok),
    ("payment-card", "high", r"(?<!\d)\d(?:[ -]?\d){12,18}(?!\d)", luhn),
    ("iban", "high", r"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,3})?\b", iban_ok),
    ("email", "medium", r"\b[\w.+-]+@[\w-]+(?:\.[\w-]+)+\b", None),
    ("phone", "medium", r"(?<![\w.])(?:\+\d|\(?0\d|\(\d{3}\))[\d\s().-]{7,}\d(?!\w)", phone_ok),
    ("ip-address", "medium", r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])", valid_ip),
    ("mac-address", "medium", r"(?i)\b(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}\b", None),
    ("home-path", "medium", r"(?:/home/|/Users/|C:\\Users\\)[\w.-]+", None),
    ("internal-host", "medium", r"(?i)\b[\w-]+(?:\.[\w-]+)*\.(?:local|lan|internal|home\.arpa|ts\.net)\b", None),
]


def data_root() -> Path:
    if os.environ.get("CLAUDE_USER_DATA"):
        return Path(os.environ["CLAUDE_USER_DATA"])
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "claude-plugins"


def load_terms() -> tuple[list[str], list[str]]:
    """Return (terms, sources). Terms come from the watchlist and pii-scanner inventory."""
    terms, sources = [], []
    wl = data_root() / "screenshotting" / "watchlist.txt"
    if wl.exists():
        terms += [l.strip() for l in wl.read_text().splitlines() if l.strip() and not l.startswith("#")]
        sources.append("watchlist")
    inv = data_root() / "pii-scanner" / "pii-inventory" / "personal.yaml"
    if inv.exists():
        try:
            import yaml

            def walk(v):
                if isinstance(v, dict):
                    for k, x in v.items():
                        if k != "notes":
                            yield from walk(x)
                elif isinstance(v, list):
                    for x in v:
                        yield from walk(x)
                elif v:
                    yield str(v)

            terms += list(walk(yaml.safe_load(inv.read_text())))
            sources.append("pii-scanner-inventory")
        except ImportError:
            sources.append("pii-scanner-inventory-skipped-no-pyyaml")
    return [t for t in terms if len(t) >= 3], sources


def ocr_lines(path: str, lang: str, min_conf: float) -> list[dict]:
    """OCR both polarities at 2x. Each line: {text, words: [(start, end, box)]}."""
    base = ImageOps.grayscale(Image.open(path).convert("RGB"))
    base = base.resize((base.width * 2, base.height * 2), Image.LANCZOS)
    lines = []
    with tempfile.TemporaryDirectory() as tmp:
        for name, img in (("normal", base), ("inverted", ImageOps.invert(base))):
            p = os.path.join(tmp, name + ".png")
            img.save(p)
            tsv = subprocess.run(["tesseract", p, "stdout", "-l", lang, "--psm", "11", "tsv"],
                                 capture_output=True, text=True, check=True).stdout
            groups: dict[tuple, list] = {}
            for r in csv.DictReader(io.StringIO(tsv), delimiter="\t", quoting=csv.QUOTE_NONE):
                if r["level"] == "5" and r["text"].strip() and float(r["conf"]) >= min_conf:
                    groups.setdefault((r["block_num"], r["par_num"], r["line_num"]), []).append(r)
            for words in groups.values():
                text, spans = "", []
                for w in words:
                    start = len(text) + (1 if text else 0)
                    text = f"{text} {w['text']}" if text else w["text"]
                    box = tuple(int(w[k]) // 2 for k in ("left", "top", "width", "height"))
                    spans.append((start, len(text), box))
                lines.append({"text": text, "words": spans})
    return lines


def span_box(line: dict, start: int, end: int, size: tuple[int, int], pad: int = 4) -> list[int]:
    boxes = [b for s, e, b in line["words"] if s < end and e > start] or [b for _, _, b in line["words"]]
    x0 = max(0, min(b[0] for b in boxes) - pad)
    y0 = max(0, min(b[1] for b in boxes) - pad)
    x1 = min(size[0], max(b[0] + b[2] for b in boxes) + pad)
    y1 = min(size[1], max(b[1] + b[3] for b in boxes) + pad)
    return [x0, y0, x1 - x0, y1 - y0]


def overlap(a, b) -> float:
    """Intersection as a share of the smaller box."""
    w = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    h = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return 0.0 if w <= 0 or h <= 0 else w * h / min(a[2] * a[3], b[2] * b[3])


def mask(s: str) -> str:
    return s[:2] + "*" * max(3, len(s) - 4) + s[-2:] if len(s) > 6 else "*" * len(s)


def run_gitleaks(lines: list[dict]) -> tuple[list[tuple], str]:
    binary = shutil.which("gitleaks")
    if not binary:
        return [], "not installed"
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp, "src")
        src.mkdir()
        (src / "ocr.txt").write_text("\n".join(l["text"] for l in lines) + "\n")
        report = Path(tmp, "report.json")
        r = subprocess.run([binary, "detect", "--no-git", "--no-banner", "--source", str(src),
                            "--report-format", "json", "--report-path", str(report), "--exit-code", "0"],
                           capture_output=True, text=True)
        if r.returncode != 0 or not report.exists():
            return [], f"failed: {r.stderr.strip()[:120]}"
        return [(h["StartLine"] - 1, h["Secret"], h["RuleID"]) for h in json.loads(report.read_text() or "[]")], "ok"


def metadata_flags(path: str) -> list[str] | str:
    if not shutil.which("exiftool"):
        return "not installed"
    out = subprocess.run(["exiftool", "-json", path], capture_output=True, text=True).stdout
    tags = json.loads(out or "[{}]")[0]
    return sorted(k for k in tags if re.search(r"GPS|Author|Creator|Owner|Serial|Artist|Comment", k))


def scan(path: str, lang: str, min_conf: float) -> dict:
    size = Image.open(path).size
    lines = ocr_lines(path, lang, min_conf)
    terms, term_sources = load_terms()
    raw = []

    def add(kind, sev, src, line, start, end):
        raw.append({"type": kind, "severity": sev, "source": src, "text": line["text"][start:end],
                    "box": span_box(line, start, end, size)})

    for line in lines:
        for kind, sev, pattern, check in DETECTORS:
            for m in re.finditer(pattern, line["text"]):
                if check is None or check(m.group()):
                    level = "low" if kind == "ip-address" and private_ip(m.group()) else sev
                    add(kind, level, "pattern", line, m.start(), m.end())
        low = line["text"].lower()
        for t in terms:
            for m in re.finditer(re.escape(t.lower()), low):
                add("watchlist", "high", "watchlist", line, m.start(), m.end())

    leaks, gitleaks_status = run_gitleaks(lines)
    for idx, secret, rule in leaks:
        if 0 <= idx < len(lines) and secret in lines[idx]["text"]:
            s = lines[idx]["text"].index(secret)
            add(f"gitleaks:{rule}", "critical", "gitleaks", lines[idx], s, s + len(secret))

    # The two OCR passes and overlapping detectors repeat findings: keep the most severe.
    raw.sort(key=lambda f: (ORDER[f["severity"]], f["source"] != "gitleaks"))
    findings = []
    for f in raw:
        if not any(overlap(f["box"], k["box"]) > 0.6 for k in findings):
            findings.append(f)
    findings.sort(key=lambda f: (f["box"][1], f["box"][0]))
    for i, f in enumerate(findings, 1):
        f["id"] = i

    return {
        "image": str(Path(path).resolve()),
        "size": list(size),
        "ocr_lines": len(lines),
        "checks": {"gitleaks": gitleaks_status, "terms": term_sources or "none configured",
                   "metadata": metadata_flags(path)},
        "counts": dict(Counter(f["severity"] for f in findings)),
        "findings": findings,
        "redact_regions": [",".join(map(str, f["box"])) for f in findings],
    }


def write_overlay(result: dict, out: Path) -> None:
    ops = []
    for f in result["findings"]:
        x, y, w, h = f["box"]
        color = COLORS[f["severity"]]
        ops.append({"type": "box", "xy": f["box"], "color": color, "width": 3})
        ops.append({"type": "marker", "xy": [max(14, x - 14), max(14, y)], "number": f["id"], "color": color, "radius": 13})
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".json") as spec:
        json.dump({"operations": ops}, spec)
        spec.flush()
        subprocess.run([sys.executable, str(Path(__file__).with_name("annotate.py")), "--input", result["image"],
                        "--spec", spec.name, "--output", str(out)], check=True, capture_output=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="First-pass risk scan of a screenshot")
    ap.add_argument("image")
    ap.add_argument("--overlay", nargs="?", const="", default=None)
    ap.add_argument("--lang", default="eng")
    ap.add_argument("--min-conf", type=float, default=30)
    ap.add_argument("--reveal", action="store_true")
    a = ap.parse_args()
    if not os.path.isfile(a.image):
        print(f"no such file: {a.image}", file=sys.stderr)
        return 1
    if not shutil.which("tesseract"):
        print("tesseract not installed: run scripts/setup-env.sh", file=sys.stderr)
        return 1
    result = scan(a.image, a.lang, a.min_conf)
    if a.overlay is not None:
        p = Path(a.image).resolve()
        out = Path(a.overlay) if a.overlay else p.parent / "flagged" / f"{p.stem}_flagged.png"
        write_overlay(result, out)
        result["overlay"] = str(out)
    if not a.reveal:
        for f in result["findings"]:
            f["text"] = mask(f["text"])
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
