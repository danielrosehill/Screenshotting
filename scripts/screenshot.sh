#!/usr/bin/env bash
# Backend-aware screenshot wrapper. Flameshot is the default; see pick_backend.
# Usage: screenshot.sh <mode> [output_path] [--clipboard]
#   full             whole desktop, all monitors
#   monitor          the monitor under the cursor
#   region           drag a selection; captures on release
#   annotate         drag a selection, draw on it in Flameshot's toolbar, confirm
#   geom:WxH+X+Y     fixed rectangle, no interaction
#   window           active window (Flameshot cannot do this: uses Spectacle or gnome-screenshot)
#   delay:N          wait N seconds, then capture the whole desktop
# Environment:
#   SCREENSHOT_BACKEND=flameshot|spectacle|grim|gnome-screenshot forces a backend
#   SCREENSHOT_DELAY=N adds a delay to any mode (e.g. time to focus a window)
# Default output: ~/Pictures/Screenshots/<ISO>.png
# Exit 1 = no backend or unsupported mode. Exit 2 = nothing captured (cancelled).

set -euo pipefail

CLIPBOARD=0
ARGS=()
for a in "$@"; do
  if [[ "$a" == --clipboard ]]; then CLIPBOARD=1; else ARGS+=("$a"); fi
done
MODE="${ARGS[0]:-full}"
OUT="${ARGS[1]:-}"

if [[ -z "$OUT" ]]; then
  OUT="$HOME/Pictures/Screenshots/$(date -u +%Y-%m-%dT%H-%M-%SZ).png"
fi
mkdir -p "$(dirname "$OUT")"

DESKTOP="${XDG_CURRENT_DESKTOP:-}"
SESSION="${XDG_SESSION_TYPE:-}"
DELAY="${SCREENSHOT_DELAY:-0}"
GEOM=""

case "$MODE" in
  delay:*) DELAY="${MODE#delay:}"; MODE=full ;;
  geom:*)  GEOM="${MODE#geom:}"; MODE=geom ;;
esac
MS=$((DELAY*1000))

have() { command -v "$1" >/dev/null; }

pick_backend() {
  if [[ -n "${SCREENSHOT_BACKEND:-}" ]]; then echo "$SCREENSHOT_BACKEND"; return; fi
  if [[ "$MODE" == window ]]; then
    if have spectacle; then echo spectacle; return; fi
    if have gnome-screenshot; then echo gnome-screenshot; return; fi
    echo none; return
  fi
  if have flameshot; then echo flameshot; return; fi
  if have spectacle; then echo spectacle; return; fi
  # grim needs wlr-screencopy, which GNOME's Mutter does not implement.
  if [[ "$SESSION" == wayland && "$DESKTOP" != *GNOME* ]] && have grim; then echo grim; return; fi
  if have gnome-screenshot; then echo gnome-screenshot; return; fi
  echo none
}

BACKEND="$(pick_backend)"
if [[ "$BACKEND" == none ]]; then
  echo "no backend for mode '$MODE': run scripts/setup-env.sh" >&2
  exit 1
fi

rm -f "$OUT"
case "$BACKEND:$MODE" in
  flameshot:full)     flameshot full -d "$MS" -r > "$OUT" ;;
  flameshot:monitor)  flameshot screen -d "$MS" -r > "$OUT" ;;
  flameshot:region)   flameshot gui -d "$MS" -s -r > "$OUT" || true ;;
  flameshot:annotate) flameshot gui -d "$MS" -r > "$OUT" || true ;;
  # "flameshot full --region" hangs with no output (v13.3.0, KDE Wayland): crop instead.
  flameshot:geom)
    have magick || { echo "ImageMagick needed for geom mode" >&2; exit 1; }
    flameshot full -d "$MS" -r 2>/dev/null | magick png:- -crop "$GEOM" +repage "$OUT" ;;
  spectacle:full)     spectacle -b -n -f -d "$MS" -o "$OUT" ;;
  spectacle:monitor)  spectacle -b -n -m -d "$MS" -o "$OUT" ;;
  spectacle:region)   spectacle -b -n -r -d "$MS" -o "$OUT" ;;
  spectacle:window)   spectacle -b -n -a -d "$MS" -o "$OUT" ;;
  grim:full)          sleep "$DELAY"; grim "$OUT" ;;
  grim:geom)
    sleep "$DELAY"
    # grim takes X,Y WxH; this wrapper takes WxH+X+Y.
    [[ "$GEOM" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]] || { echo "bad geometry: $GEOM" >&2; exit 1; }
    grim -g "${BASH_REMATCH[3]},${BASH_REMATCH[4]} ${BASH_REMATCH[1]}x${BASH_REMATCH[2]}" "$OUT" ;;
  grim:region)
    have slurp || { echo "slurp not installed" >&2; exit 1; }
    sleep "$DELAY"
    SEL="$(slurp)" || exit 2
    grim -g "$SEL" "$OUT" ;;
  gnome-screenshot:full)   gnome-screenshot -d "$DELAY" -f "$OUT" ;;
  gnome-screenshot:region) gnome-screenshot -a -f "$OUT" ;;
  gnome-screenshot:window) gnome-screenshot -w -d "$DELAY" -f "$OUT" ;;
  *) echo "mode '$MODE' is not supported by $BACKEND" >&2; exit 1 ;;
esac

if [[ ! -s "$OUT" ]]; then
  rm -f "$OUT"
  echo "capture produced no output (cancelled?)" >&2
  exit 2
fi

if [[ $CLIPBOARD == 1 ]]; then
  if [[ "$SESSION" == wayland ]] && have wl-copy; then wl-copy --type image/png < "$OUT"
  elif have xclip; then xclip -selection clipboard -t image/png -i "$OUT"
  else echo "no clipboard tool (wl-copy or xclip): image saved only" >&2
  fi
fi

echo "$OUT"
