---
name: capture-and-annotate
description: "Take a screenshot and annotate it in one step: \"grab this and draw an arrow\", \"screenshot and label it\", \"circle this\"."
---

# Capture and Annotate

Compose `screenshot` + `annotate` into one step. Use when the user says things like "screenshot this and circle X", "grab the active window and add a numbered marker at 200,300", or "capture a region and label it 'Step 1'".

## Flow

1. Run the screenshot script to a temp path:
   ```bash
   TMP=/tmp/cap-$RANDOM.png
   bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" "$MODE" "$TMP"
   ```
2. Verify the temp file exists and is non-empty. If not (e.g. region selection cancelled), stop and report — do not produce an empty annotated file.
3. Build the annotation spec JSON.
4. Run the annotator, writing to the user's chosen final path:
   ```bash
   python3 "$CLAUDE_PLUGIN_ROOT/scripts/annotate.py" \
     --input "$TMP" --spec "$SPEC" --output "$FINAL"
   ```
5. Delete the temp file (`rm "$TMP"`).
6. Report the final path.

## When the user wants to draw by hand

Skip the flow above and run one command, which captures and opens Flameshot's annotation toolbar:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/screenshot.sh" annotate "$FINAL"
```

## Default output

If the user doesn't give a final path, write to `~/Pictures/Screenshots/<ISO-timestamp>-annotated.png`. The captured original is the temp file, so deleting it after annotation is fine — there's no "original" to preserve. If the user *does* want the unannotated capture saved too, run the screenshot script first to a real path, then run `annotate` against it (which will produce a sibling `annotated/` folder, leaving the original untouched).

## Coordinate guidance

User coordinates are in the captured image's coordinate space, not the screen's. For region captures the user can't know exact pixel coordinates in advance — capture first, report the resulting image dimensions, then ask for coordinates. Or accept relative descriptors (`center`, `top-left`, `bottom-right`) and translate to pixels after capture.

## On failure

If annotation fails, keep the temp file and report its path so the user can retry.
