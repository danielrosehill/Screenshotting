#!/usr/bin/env bash
# Check and install every CLI the screenshotting plugin uses.
# Usage: setup-env.sh [--check] [--all]
#   (no flags)  install anything missing from the core set
#   --check     report only, install nothing; exit 1 if a core tool is missing
#   --all       include optional tools (GUI annotation editor)
# Idempotent. Supports apt, dnf and pacman. Installing needs sudo.

set -euo pipefail

CHECK=0; ALL=0
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    --all)   ALL=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

. /etc/os-release 2>/dev/null || true
case "${ID:-unknown}:${ID_LIKE:-}" in
  ubuntu*|debian*|linuxmint*|pop*|*:*debian*) PM=apt ;;
  fedora*|rhel*|centos*|*:*fedora*)           PM=dnf ;;
  arch*|manjaro*|endeavouros*|*:*arch*)       PM=pacman ;;
  *) PM=none ;;
esac
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
SESSION="${XDG_SESSION_TYPE:-unknown}"

# binary|apt package|dnf package|pacman package|tier|purpose
# "-" means not packaged there: install it by hand.
TOOLS=(
  "flameshot|flameshot|flameshot|flameshot|core|default screenshot backend"
  "magick|imagemagick|ImageMagick|imagemagick|core|redaction, cropping, PDF fallback"
  "PIL|python3-pil|python3-pillow|python-pillow|core|annotation and risk scan"
  "tesseract|tesseract-ocr|tesseract|tesseract-data-eng|core|OCR and risk scan word boxes"
  "gitleaks|gitleaks|-|gitleaks|core|secret detection in the risk scan"
  "exiftool|libimage-exiftool-perl|perl-Image-ExifTool|perl-image-exiftool|core|metadata check in the risk scan"
  "img2pdf|img2pdf|img2pdf|img2pdf|core|lossless image to PDF"
  "cwebp|webp|libwebp-tools|libwebp|core|WebP conversion"
)
case "$DESKTOP" in
  *KDE*) TOOLS+=("spectacle|kde-spectacle|spectacle|spectacle|core|active-window capture") ;;
  *GNOME*) TOOLS+=("gnome-screenshot|gnome-screenshot|gnome-screenshot|gnome-screenshot|core|active-window capture") ;;
  *sway*|*Hyprland*|*wlroots*)
    TOOLS+=("grim|grim|grim|grim|core|Wayland capture" "slurp|slurp|slurp|slurp|core|Wayland region selection") ;;
esac
if [[ "$SESSION" == wayland ]]; then
  TOOLS+=("wl-copy|wl-clipboard|wl-clipboard|wl-clipboard|core|copy images to the clipboard")
else
  TOOLS+=("xclip|xclip|xclip|xclip|core|copy images to the clipboard")
fi
TOOLS+=("ksnip|ksnip|ksnip|ksnip|optional|GUI editor for annotating existing images")

present() {
  if [[ "$1" == PIL ]]; then python3 -c 'import PIL' 2>/dev/null; else have "$1"; fi
}

echo "system: ${ID:-unknown} ($PM), desktop $DESKTOP, session $SESSION"
TO_INSTALL=(); MANUAL=(); CORE_MISSING=0
for row in "${TOOLS[@]}"; do
  IFS='|' read -r bin apt_pkg dnf_pkg pac_pkg tier purpose <<< "$row"
  if present "$bin"; then
    printf '  ok       %-18s %s\n' "$bin" "$purpose"
    continue
  fi
  printf '  missing  %-18s %s (%s)\n' "$bin" "$purpose" "$tier"
  [[ "$tier" == core ]] && CORE_MISSING=1
  [[ "$tier" == optional && $ALL == 0 ]] && continue
  case "$PM" in
    apt) pkg="$apt_pkg" ;;
    dnf) pkg="$dnf_pkg" ;;
    pacman) pkg="$pac_pkg" ;;
    *) pkg="-" ;;
  esac
  if [[ "$pkg" == - ]]; then MANUAL+=("$bin"); else TO_INSTALL+=("$pkg"); fi
done

if [[ $CHECK == 1 ]]; then exit "$CORE_MISSING"; fi

if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
  echo "installing: ${TO_INSTALL[*]}"
  case "$PM" in
    apt)    sudo apt-get update -qq; sudo apt-get install -y "${TO_INSTALL[@]}" ;;
    dnf)    sudo dnf install -y "${TO_INSTALL[@]}" ;;
    pacman) sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}" ;;
  esac
fi

if [[ ${#MANUAL[@]} -gt 0 ]]; then
  echo "install by hand, no package for this system: ${MANUAL[*]}" >&2
fi
echo "done"
