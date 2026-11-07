---
name: redact
description: "Pixelate, blur or black out regions of an existing screenshot. For live web pages prefer spoof-page-screenshot."
---

# Redact

For a page open in a browser, `spoof-page-screenshot` usually gives a better result: stand-in text looks real, where pixelated blocks draw attention. Use this skill for desktop apps, images already captured, and page content that cannot be spoofed (images, canvas).

Hide sensitive regions of an image. Use this rather than `annotate` when the goal is privacy — defaults are tuned to make the redaction non-recoverable.

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

## Why pixelate by default

Gaussian blur on text is reversible with deconvolution; coarse pixelation isn't. The script picks a block size of `min(W,H)/8` (floor 16) so even a small region collapses to ≤8 cells per side.

## EXIF strip

The script appends `-strip` to the ImageMagick pipeline so GPS, original timestamp, and device metadata don't survive into the redacted output.

## Behaviour rules

- If the user asks to "blur a face/text" without coordinates, ask for the bounding box — this skill does not detect content.
- After writing, report: output path, regions redacted, method per region, and a one-line reminder that the original still contains the unredacted content.
