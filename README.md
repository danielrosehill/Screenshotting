# Screenshotting

A Claude Code plugin for Linux screenshots from the CLI: capture, annotate, OCR, and hide private data before anything is shared. Successor to `image-annotation`, which it renames and extends.

Designed for Ubuntu and other Linux desktops, on X11 and Wayland.

## Skills

| Skill | What it does |
|---|---|
| `screenshot` | Full screen, monitor, select area, fixed rectangle, active window, delayed; optional clipboard copy |
| `annotate` | Arrows, boxes, text, highlights and numbered markers via JSON spec, or a GUI editor |
| `capture-and-annotate` | Capture and annotate in one step |
| `ocr-screenshot` | Extract text with Claude's vision, Tesseract, or any local OCR command |
| `spoof-page-screenshot` | Swap private text in a live web page for stand-ins, verify, then capture |
| `redact` | Pixelate, blur or black out regions of an existing image |
| `batch-to-webp` | Bulk WebP conversion |
| `batch-to-pdf` | Bundle images into one PDF |
| `install-deps` | Install whatever is missing |

## Originals-clean rule

Source images are never modified. Output goes to `<dir>/annotated/`, `<dir>/redacted/` or `<dir>/webp/`.

## Tools

| Capability | Default | Alternatives |
|---|---|---|
| Capture | Flameshot | Spectacle, grim + slurp, gnome-screenshot |
| Active-window capture | Spectacle | gnome-screenshot (Flameshot has no window mode) |
| Annotation, scripted | Pillow (`scripts/annotate.py`) | |
| Annotation, by hand | Flameshot at capture time | satty, swappy, ksnip for existing images |
| OCR | Claude's vision | Tesseract, any local OCR command |
| Page spoofing | `scripts/spoof-dom.js` in Claude in Chrome | Any browser tool with JS evaluate, or the DevTools console |
| Redaction | ImageMagick | |

Flameshot is the default because it has the better CLI and runs across desktops. Set `SCREENSHOT_BACKEND` to use another.

## Installation

```bash
claude plugins marketplace add danielrosehill/Claude-Code-Plugins
claude plugins install screenshotting@danielrosehill
```

Upgrading from `image-annotation`: uninstall it and install `screenshotting`. Skill names are unchanged.

## License

MIT
