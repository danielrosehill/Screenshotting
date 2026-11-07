#!/usr/bin/env bash
# Install dependencies for the screenshotting plugin.
# Detects distro and desktop session, installs only what is missing.
# Idempotent: safe to re-run.

set -euo pipefail

log() { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- Detect distro --------------------------------------------------------
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  DISTRO="${ID:-unknown}"
else
  DISTRO=unknown
fi

# --- Detect desktop session ----------------------------------------------
SESSION="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"

log "distro=$DISTRO session=$SESSION desktop=$DESKTOP"

# --- Pick screenshot backend -------------------------------------------
# Flameshot is the default everywhere; the others fill the gaps it leaves.
SCREENSHOT_PKGS=("flameshot")
case "$DESKTOP" in
  *KDE*)        SCREENSHOT_PKGS+=("kde-spectacle") ;;
  *sway*|*Hyprland*|*wlroots*) SCREENSHOT_PKGS+=("grim" "slurp") ;;
esac

# --- Build install list per distro --------------------------------------
case "$DISTRO" in
  ubuntu|debian|linuxmint|pop)
    INSTALLER="sudo apt install -y"
    REFRESH="sudo apt update"
    BASE_PKGS=(imagemagick python3-pil img2pdf webp)
    ;;
  fedora|rhel|centos)
    INSTALLER="sudo dnf install -y"
    REFRESH="true"
    BASE_PKGS=(ImageMagick python3-pillow img2pdf libwebp-tools)
    SCREENSHOT_PKGS=("${SCREENSHOT_PKGS[@]/kde-spectacle/spectacle}")
    ;;
  arch|manjaro|endeavouros)
    INSTALLER="sudo pacman -S --needed --noconfirm"
    REFRESH="true"
    BASE_PKGS=(imagemagick python-pillow img2pdf libwebp)
    SCREENSHOT_PKGS=("${SCREENSHOT_PKGS[@]/kde-spectacle/spectacle}")
    ;;
  *)
    err "Unsupported distro: $DISTRO. Install manually: imagemagick, python3-pillow, img2pdf, webp tools, plus a screenshot backend."
    exit 1
    ;;
esac

# --- Filter to missing only ---------------------------------------------
TO_INSTALL=()

needs() {
  local bin="$1" pkg="$2"
  if have "$bin"; then
    log "ok: $bin"
  else
    TO_INSTALL+=("$pkg")
  fi
}

needs magick imagemagick
have python3 && python3 -c 'import PIL' 2>/dev/null && log "ok: python3-pil" || TO_INSTALL+=("${BASE_PKGS[1]}")
needs img2pdf img2pdf
needs cwebp "${BASE_PKGS[3]}"
case "$DISTRO" in
  ubuntu|debian|linuxmint|pop) needs tesseract tesseract-ocr ;;
  *) needs tesseract tesseract ;;
esac

for pkg in "${SCREENSHOT_PKGS[@]}"; do
  bin="$pkg"
  case "$pkg" in
    kde-spectacle) bin=spectacle ;;
    libwebp-tools|libwebp|webp) bin=cwebp ;;
  esac
  needs "$bin" "$pkg"
done

if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
  log "all dependencies already present"
  exit 0
fi

log "installing: ${TO_INSTALL[*]}"
$REFRESH
$INSTALLER "${TO_INSTALL[@]}"

log "done"
