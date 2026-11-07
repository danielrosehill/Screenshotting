---
name: annotate
description: "Annotate a screenshot from the CLI: arrows, text callouts, boxes, highlights, numbered markers via JSON spec, or a GUI editor."
---

# Annotate

Apply visual annotations to an existing image file via the bundled Pillow-based annotator.

## Originals-clean rule (non-negotiable)

This skill **never modifies the original image** unless the user explicitly says so. Default output behaviour:

- If `--output` is given, write there.
- Else, write to `<input_dir>/annotated/<stem>_annotated<ext>` (directory created if missing).
- `--in-place` overwrites the input. Only pass this when the user has explicitly confirmed they want the original replaced.

This rule is enforced by `scripts/annotate.py`. Do not bypass it by calling ImageMagick directly to write back over the input.

## Just run the script

1. Build a JSON spec describing the operations and write it to a temp file (e.g. `/tmp/annot-spec-<random>.json`).
2. Invoke the annotator:

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/annotate.py" \
  --input  "$INPUT" \
  --spec   "$SPEC_JSON" \
  [--output "$OUTPUT"]    # optional; default = <dir>/annotated/<stem>_annotated.<ext>
  [--in-place]            # only with explicit user consent
```

3. The script prints the output path on success. Delete the temp spec file.

## Spec format

```json
{
  "operations": [
    {"type": "arrow",     "from": [100, 200], "to": [300, 200], "color": "red", "width": 4},
    {"type": "box",       "xy": [50, 50, 200, 100], "color": "red", "width": 3},
    {"type": "text",      "xy": [60, 40], "content": "Look here", "color": "red", "size": 28, "background": true},
    {"type": "callout",   "target": [400, 300], "label": [500, 200], "content": "Step 1", "color": "red", "size": 22},
    {"type": "highlight", "xy": [10, 10, 200, 50], "color": "yellow", "opacity": 96},
    {"type": "marker",    "xy": [120, 240], "number": 1, "color": "red", "radius": 18}
  ]
}
```

Coordinates are pixels from the top-left of the image.

## Defaults to assume when the user is loose

- `color`: `red` for arrows/boxes/markers; `yellow` for highlights.
- Text on busy backgrounds: keep `"background": true` (translucent white pad with red outline) unless the user says otherwise.
- Font: bundled DejaVu Sans Bold (always present after `install-deps`).

## When the user wants something simple

For a one-shot "draw an arrow at X→Y", still go through this script with a one-op spec. Don't reach for a separate ImageMagick invocation — keeping a single code path keeps the originals-clean rule airtight.

## Interactive annotation

The JSON spec suits annotations the agent can place itself. When the user wants to draw by hand:

- **While capturing:** `bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" annotate <output_path>` opens Flameshot's selection with its toolbar (arrows, boxes, text, blur). The user confirms in the toolbar.
- **On an existing image:** `bash "$CLAUDE_PLUGIN_ROOT/scripts/edit.sh" <image> [output_path]` opens satty, swappy or ksnip, whichever is installed first (`SCREENSHOT_EDITOR` forces one). Flameshot cannot open an existing file. The original stays untouched and the output defaults to `<dir>/annotated/<stem>_annotated.png`. Exit 2 means the editor closed without saving.
