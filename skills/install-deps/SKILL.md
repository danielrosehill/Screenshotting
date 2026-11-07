---
name: install-deps
description: "Install what the screenshotting plugin needs: Flameshot, Spectacle or grim, ImageMagick, Pillow, Tesseract, img2pdf, cwebp."
---

# Install Dependencies

Use this skill the first time the user runs an annotation/screenshot/batch skill, or whenever a downstream skill reports a missing tool.

## Just run the script

The plugin ships an idempotent setup script — invoke it and report the output.

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/setup-env.sh"
```

It detects:
- distro from `/etc/os-release` (apt / dnf / pacman supported)
- desktop session (`XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`)

…then installs only the missing tools from this set:
- `imagemagick` (binary `magick`) — annotation, redaction, PDF fallback
- `python3-pillow` — Pillow-based annotator
- `img2pdf` — lossless image → PDF
- `webp` / `libwebp-tools` (binary `cwebp`) — WebP conversion
- `tesseract` — local OCR
- `flameshot` — default screenshot backend, on every desktop
- `kde-spectacle` on KDE (active-window captures, which Flameshot lacks); `grim` + `slurp` on wlroots Wayland

Not installed by the script:

- A GUI editor for existing images: `ksnip` or `swappy` from apt, `satty` where packaged.
- OCR languages beyond English: `tesseract-ocr-<lang>` on apt, e.g. `tesseract-ocr-heb`.

## Behaviour rules

- Re-run anytime — it's idempotent and only installs what's missing.
- If `sudo` is unavailable or the distro is unsupported, the script prints what to install manually; relay that to the user.
- After running, list which screenshot backend(s) are now available so downstream skills know what to pick.
