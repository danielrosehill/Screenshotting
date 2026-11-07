---
name: batch-to-webp
description: "Batch-convert screenshots to WebP for the web, lossy or lossless. Originals stay untouched; output in <dir>/webp/."
---

# Batch to WebP

Convert one or many images to WebP via `cwebp`. Useful after annotation when the user is preparing screenshots for a blog post, docs site, or anywhere bandwidth matters.

## Originals-clean rule

Never overwrite or delete the source files. Output defaults to `<dirname>/webp/<stem>.webp` next to each input — a single sibling subfolder collects the converted set, leaving originals clean.

## Just run the script

Convert specific files:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/to-webp.sh" \
  [--quality 85] [--lossless] [--out-dir DIR] \
  FILE [FILE ...]
```

Or convert by glob:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/to-webp.sh" \
  --glob "/path/to/dir/*.png" [--quality 85] [--out-dir DIR]
```

## Defaults

- `--quality 85` — solid balance of size vs visual fidelity for screenshots.
- Lossy by default. Pass `--lossless` for diagrams, UI screenshots with sharp text, or anything where compression artefacts on edges would be visible.
- `--out-dir` overrides the default `webp/` sibling and dumps everything into one folder (handy for blog uploads).

## Output

The script prints each converted file path on stdout and a `converted=N skipped=M` summary on stderr. Surface both to the user.

## When to recommend lossless vs lossy

- Annotated screenshots with text/arrows: **lossless** — JPEG-style ringing on red arrows looks bad.
- Photographs / heroes: lossy at q=80–85.
- If unsure, convert both and let the user pick.
