#!/usr/bin/env bash
# HY300 Minimal Black - Linux installer (interactive, English / Português-BR). MIT License.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hy300-common.sh
. "$ROOT/lib/hy300-common.sh"
RUN=""

detect_pm() {
  if command -v apt-get >/dev/null 2>&1; then PKGS="build-essential git pkg-config libusb-1.0-0-dev"; INSTALL="sudo apt-get install -y"
  elif command -v dnf >/dev/null 2>&1; then PKGS="gcc git pkgconf-pkg-config libusb1-devel"; INSTALL="sudo dnf install -y"
  elif command -v pacman >/dev/null 2>&1; then PKGS="base-devel git libusb pkgconf"; INSTALL="sudo pacman -S --needed --noconfirm"
  elif command -v zypper >/dev/null 2>&1; then PKGS="gcc git pkg-config libusb-1_0-devel"; INSTALL="sudo zypper install -y"
  else PKGS="a C compiler, git, pkg-config, libusb-1.0 development files"; INSTALL=""; fi
}
have() { command -v "$1" >/dev/null 2>&1; }
check_one() { if eval "$2"; then printf '  %-26s %s\n' "$1" "$(t dep_ok)"; else printf '  %-26s %s\n' "$1" "$(t dep_missing)"; MISSING=1; fi; }

check_deps() {
  say step_deps; detect_pm; MISSING=0
  check_one "C compiler (cc/gcc/clang)" 'have cc || have gcc || have clang'
  check_one "git" 'have git'
  check_one "pkg-config" 'have pkg-config'
  check_one "libusb-1.0 (headers)" 'pkg-config --exists libusb-1.0 2>/dev/null'
  if [ "$MISSING" = 1 ]; then
    if [ -n "$INSTALL" ]; then
      if ask_yes ask_install; then $INSTALL $PKGS || die "$(t build_fail)"; else t manual_cmd; echo "  $INSTALL $PKGS"; exit 1; fi
    else t manual_cmd; echo "  $PKGS"; exit 1; fi
    have pkg-config && pkg-config --exists libusb-1.0 || die "libusb-1.0 still not found"
  fi
  # USB permission for the FEL device (VID 1f3a, PID efe8): udev rule, otherwise fall back to sudo
  if [ "$(id -u)" != 0 ]; then
    if grep -qsi '1f3a' /etc/udev/rules.d/*.rules; then RUN=""
    else
      case "$LANG_SEL" in
        pt) echo "Para falar com o aparelho em modo FEL sem root, instalo uma regra udev (só para 1f3a:efe8).";;
        *)  echo "To talk to the device in FEL mode without root, I can install a udev rule (only for 1f3a:efe8).";;
      esac
      if ask_yes ask_udev; then
        printf 'SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", MODE="0666"\n' | sudo tee /etc/udev/rules.d/99-hy300-fel.rules >/dev/null \
          && sudo udevadm control --reload-rules && sudo udevadm trigger && RUN="" || RUN="sudo"
      else RUN="sudo"; fi
    fi
  fi
}

parse_args "$@"
main_flow
