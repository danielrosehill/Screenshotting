---
name: redact
description: "Pixelate, blur or black out regions of an existing screenshot. For live web pages prefer spoof-page-screenshot."
---

# Redact

For a page open in a browser, `spoof-page-screenshot` usually gives a better result: stand-in text looks real, where pixelated blocks draw attention. Use this skill for desktop apps, images already captured, and page content that cannot be spoofed (images, canvas).

Hide sensitive regions of an image. Use this rather than `annotate` when the goal is privacy. `scan-screenshot` supplies the regions.

## Originals-clean rule

This skill **never overwrites the original**. Output goes to `<input_dir>/redacted/<stem>_redacted<ext>` by default, or to `--output PATH` if supplied. There is no in-place mode for redaction — keep the source intact (or delete it yourself once you've verified the redacted copy).

## Just run the script

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/redact.sh" \
  --input  "$INPUT" \
  [--output "$OUTPUT"] \
  [--method pixelate|blur|solid] \
  --region X,Y,W,H [--region X,Y,W,H ...]
```

## Choosing a method

Pixelate is the default because it looks tidy. Use `--method solid` for passwords, keys and anything else that must not be recoverable: tools exist that reconstruct pixelated text, and blur can be partly reversed too. Only a solid fill removes the pixels.

## EXIF strip

The script appends `-strip` to the ImageMagick pipeline so GPS, original timestamp, and device metadata don't survive into the redacted output.

## Behaviour rules

- If the user gives no coordinates, get them from `scan-screenshot` for text. For faces and other non-text content, read the image dimensions and locate the region by eye.
- After writing, report: output path, regions redacted, method per region, and a one-line reminder that the original still contains the unredacted content.
