---
name: setup-environment
description: "Set up the screenshotting plugin: list the CLIs it uses, check which are missing, run the installer script."
---

# Set Up the Environment

Use this the first time the plugin runs, when the user asks what it needs, or when a skill reports a missing tool.

## Steps

1. Check what is there. This changes nothing:
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/setup-env.sh" --check
   ```
2. Show the user the missing tools and run the installer. It needs sudo, so if it fails on a password, ask the user to run it themselves.
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/setup-env.sh"        # core set
   bash "$CLAUDE_PLUGIN_ROOT/scripts/setup-env.sh" --all  # plus the GUI editor
   ```
3. Run `--check` again and report the result.

The script is idempotent, skips what is installed, and supports apt, dnf and pacman.

## What it installs

| CLI | Used for | Used by | Tier |
|---|---|---|---|
| `flameshot` | Default capture, annotating during capture | `screenshot`, `capture-and-annotate` | Core |
| `spectacle` (KDE), `gnome-screenshot` (GNOME) | Active-window capture | `screenshot` | Core on that desktop |
| `grim`, `slurp` | Capture on wlroots Wayland | `screenshot` | Core on that desktop |
| `wl-copy` or `xclip` | Clipboard copy | `screenshot` | Core |
| `magick` | Redaction, cropping | `redact`, `screenshot`, `ocr-screenshot` | Core |
| Pillow | Annotation | `annotate`, `scan-screenshot` | Core |
| `tesseract` | OCR, word boxes | `ocr-screenshot`, `scan-screenshot` | Core |
| `gitleaks` | Secret detection | `scan-screenshot` | Core |
| `exiftool` | Metadata check | `scan-screenshot` | Core |
| `img2pdf` | Lossless PDF | `batch-to-pdf` | Core |
| `cwebp` | WebP conversion | `batch-to-webp` | Core |
| `ksnip` | Annotating existing images | `annotate` | Optional (`--all`) |

## Not installed

- **OCR languages beyond English:** `tesseract-ocr-<lang>` on apt, e.g. `tesseract-ocr-heb`.
- **`satty`, `swappy`:** alternative editors, used automatically when present.
- **Microsoft Presidio:** better name and address detection, but it needs a large spaCy model. `scan-screenshot` covers that gap with Claude's vision or a watchlist.

## Notes

- The scripts call `magick`, the ImageMagick 7 binary. A distro shipping ImageMagick 6 only provides `convert`, which shows as missing here.
- Claude in Chrome, used by `spoof-page-screenshot`, is a browser extension, so this script does not install it.
- On Fedora, `gitleaks` has no package: install it from its GitHub releases.
