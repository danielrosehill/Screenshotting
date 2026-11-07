---
name: ocr-screenshot
description: "Screenshot and OCR: extract text from the screen or an image with Claude's vision, Tesseract or a local OCR model."
---

# OCR Screenshot

## Inputs

- An image path, or a capture mode from the `screenshot` skill.
- Optional: an engine and language. Otherwise the configured engine applies.

## Steps

1. If there is no image yet, capture one with `scripts/screenshot.sh`. A `region` capture gives the cleanest text.
2. Pick the engine, first match wins:
   1. The one the user named.
   2. `ocr.engine` in the config file below.
   3. `claude`.
3. Extract the text:
   - **`claude`:** read the image file directly and transcribe it. No install needed. This is the best route for UI layouts, tables and mixed languages, but the image goes to the model provider.
   - **`tesseract` or `command`:** run the script below. The image stays on the machine.
     ```bash
     bash "$CLAUDE_PLUGIN_ROOT/scripts/ocr.sh" <image> [--engine tesseract|command] [--lang eng] [--psm N] [--raw]
     ```
4. Return the text, or write it to the file the user asked for.

## Local engines

`tesseract` output is preprocessed first: grayscale, 2x upscale, and inverted when the image is dark. `--raw` skips that. `--psm 11` helps with scattered UI text, `--psm 6` with one uniform block. Combine languages with `--lang eng+heb` once the language pack is installed.

`command` runs any local OCR CLI or model wrapper that prints text to stdout. Set it in the config, with `{image}` where the path goes.

## Data storage

Optional config, created only when the user sets a default:

`${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/screenshotting/config.json`

```json
{"ocr": {"engine": "command", "lang": "eng", "command": "my-ocr --input {image}"}}
```

## Notes

- If the screenshot holds sensitive content and the user wants it kept off external services, use a local engine.
- A heavy local model belongs on a machine that can run it. `command` can call a remote endpoint if the user's wrapper does.
- Exit 3 from `ocr.sh` means the engine is `claude`: read the image instead.
