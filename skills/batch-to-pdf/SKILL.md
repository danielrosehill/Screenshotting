---
name: batch-to-pdf
description: "Bundle screenshots into one PDF for tutorials, bug reports or step-by-step guides. Keeps order; sources stay untouched."
---

# Batch to PDF

Combine a set of images, in order, into a single PDF document. Commonly used to produce a step-by-step tutorial after running `annotate` over a series of screenshots.

## Originals-clean rule

Never modifies the input images. Only writes the single PDF at `--output`.

## Just run the script

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/to-pdf.sh" \
  --output "$OUT_PDF" \
  FILE [FILE ...]
```

Or with a glob (expanded by the shell, alphabetical order):

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/to-pdf.sh" \
  --output "$OUT_PDF" \
  --glob "/path/to/annotated/*.png"
```

## Order matters

The PDF page order follows the argument order. If the user has filenames like `step-01-...`, `step-02-...`, alphabetical glob expansion gives the right order. If they have unordered names, list the files explicitly in the order they want.

## Backend selection

The script prefers `img2pdf` (lossless, no re-encoding for JPEGs — much smaller PDFs) and falls back to `magick` if img2pdf isn't installed. Run the `setup-environment` skill once to get img2pdf.

## Common workflow

1. `screenshot` × N → series of PNGs in `~/Pictures/Screenshots/`
2. `annotate` × N → annotated copies in `~/Pictures/Screenshots/annotated/`
3. `batch-to-pdf` → `~/Documents/tutorial.pdf` from the `annotated/` folder

Encourage the user to put the PDF outside the screenshots tree (e.g. `~/Documents/`) so it doesn't get swept up by future glob runs.
