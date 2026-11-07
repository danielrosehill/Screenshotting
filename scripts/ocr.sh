#!/usr/bin/env bash
# Local OCR of an image, text to stdout.
# Usage: ocr.sh <image> [--engine tesseract|command] [--lang eng] [--psm N] [--raw]
#   --raw   skip the grayscale/upscale/dark-theme preprocessing
# Config (optional):
#   ${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/screenshotting/config.json
#   {"ocr": {"engine": "tesseract", "lang": "eng", "command": "my-ocr {image}"}}
# "command" is any local OCR CLI that prints text to stdout; {image} is the file path.
# Engine "claude" means the agent reads the image itself, so this script declines it.

set -euo pipefail

IMG="${1:?usage: ocr.sh <image> [--engine E] [--lang L] [--psm N] [--raw]}"
shift
[[ -f "$IMG" ]] || { echo "no such file: $IMG" >&2; exit 1; }

CONFIG="${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/screenshotting/config.json"
cfg() {
  [[ -f "$CONFIG" ]] || return 0
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("ocr",{}).get(sys.argv[2],""))' "$CONFIG" "$1"
}

ENGINE="$(cfg engine)"; LANGS="$(cfg lang)"; COMMAND="$(cfg command)"
PSM=3; RAW=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) ENGINE="$2"; shift 2 ;;
    --lang)   LANGS="$2"; shift 2 ;;
    --psm)    PSM="$2"; shift 2 ;;
    --raw)    RAW=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
ENGINE="${ENGINE:-tesseract}"; LANGS="${LANGS:-eng}"

case "$ENGINE" in
  claude)
    echo "engine is 'claude': read the image directly instead of running this script" >&2
    exit 3 ;;
  command)
    [[ -n "$COMMAND" ]] || { echo "engine 'command' needs ocr.command in $CONFIG" >&2; exit 1; }
    # The path goes through the environment, so spaces and quotes in it are safe.
    IMAGE="$IMG" bash -c "${COMMAND//\{image\}/\"\$IMAGE\"}"
    ;;
  tesseract)
    command -v tesseract >/dev/null || { echo "tesseract not installed: run scripts/setup-env.sh" >&2; exit 1; }
    if [[ $RAW == 1 ]] || ! command -v magick >/dev/null; then
      tesseract "$IMG" stdout -l "$LANGS" --psm "$PSM" 2>/dev/null
      exit 0
    fi
    TMP="$(mktemp --suffix=.png)"
    trap 'rm -f "$TMP"' EXIT
    # Tesseract is tuned for dark text on light, at print size: UI text needs help.
    MEAN="$(magick "$IMG" -colorspace Gray -format '%[fx:mean]' info:)"
    NEGATE=()
    if awk -v m="$MEAN" 'BEGIN{exit !(m<0.5)}'; then NEGATE=(-negate); fi
    magick "$IMG" -colorspace Gray "${NEGATE[@]}" -resize 200% "$TMP"
    tesseract "$TMP" stdout -l "$LANGS" --psm "$PSM" 2>/dev/null
    ;;
  *) echo "unknown engine: $ENGINE" >&2; exit 1 ;;
esac
