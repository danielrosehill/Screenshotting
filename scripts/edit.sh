#!/usr/bin/env bash
# Open an existing image in a GUI annotation editor; the original is never touched.
# Flameshot only annotates at capture time (screenshot.sh annotate), so it is not here.
# Usage: edit.sh <image> [output_path]
#   SCREENSHOT_EDITOR=satty|swappy|ksnip forces an editor.
# Default output: <dir>/annotated/<stem>_annotated.png
# Blocks until the editor closes. Exit 1 = no editor. Exit 2 = nothing saved.

set -euo pipefail

IN="${1:?usage: edit.sh <image> [output_path]}"
[[ -f "$IN" ]] || { echo "no such file: $IN" >&2; exit 1; }
DIR="$(cd "$(dirname "$IN")" && pwd)"
STEM="$(basename "${IN%.*}")"
OUT="${2:-$DIR/annotated/${STEM}_annotated.png}"
mkdir -p "$(dirname "$OUT")"

have() { command -v "$1" >/dev/null; }
EDITOR_BIN="${SCREENSHOT_EDITOR:-}"
if [[ -z "$EDITOR_BIN" ]]; then
  for e in satty swappy ksnip; do
    if have "$e"; then EDITOR_BIN="$e"; break; fi
  done
fi

case "$EDITOR_BIN" in
  satty)  satty --filename "$IN" --output-filename "$OUT" ;;
  swappy) swappy -f "$IN" -o "$OUT" ;;
  # ksnip has no output flag: it edits a copy, and the user saves with Ctrl+S.
  ksnip)  cp "$IN" "$OUT"; BEFORE="$(sha256sum < "$OUT")"; ksnip -e "$OUT"
          if [[ "$(sha256sum < "$OUT")" == "$BEFORE" ]]; then rm -f "$OUT"; fi ;;
  "")     echo "no annotation editor found: install satty, swappy or ksnip" >&2; exit 1 ;;
  *)      echo "unknown editor: $EDITOR_BIN" >&2; exit 1 ;;
esac

[[ -s "$OUT" ]] || { echo "editor closed without saving" >&2; exit 2; }
echo "$OUT"
