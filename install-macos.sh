#!/usr/bin/env bash
# HY300 Dark Minimal - macOS installer (interactive, English / Português-BR). MIT License.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hy300-common.sh
. "$ROOT/lib/hy300-common.sh"
RUN=""
have() { command -v "$1" >/dev/null 2>&1; }
check_one() { if eval "$2"; then printf '  %-26s %s\n' "$1" "$(t dep_ok)"; else printf '  %-26s %s\n' "$1" "$(t dep_missing)"; MISSING=1; fi; }

check_deps() {
  say step_deps; MISSING=0
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  check_one "Xcode Command Line Tools" 'xcode-select -p >/dev/null 2>&1 && have cc'
  check_one "git" 'have git'
  check_one "Homebrew" 'have brew'
  check_one "pkg-config" 'have pkg-config'
  check_one "libusb-1.0" 'pkg-config --exists libusb-1.0 2>/dev/null'
  if ! xcode-select -p >/dev/null 2>&1; then
    case "$LANG_SEL" in pt) echo "Instale as Ferramentas de Linha de Comando do Xcode:  xcode-select --install   (depois rode este script de novo)";; *) echo "Install the Xcode Command Line Tools:  xcode-select --install   (then run this script again)";; esac
    exit 1
  fi
  if ! have brew; then
    case "$LANG_SEL" in pt) echo "Homebrew não encontrado. Instale em https://brew.sh e rode este script de novo.";; *) echo "Homebrew not found. Install it from https://brew.sh and run this script again.";; esac
    exit 1
  fi
  if [ "$MISSING" = 1 ]; then
    if ask_yes ask_install; then brew install libusb pkg-config || die "$(t build_fail)"
    else t manual_cmd; echo "  brew install libusb pkg-config"; exit 1; fi
    pkg-config --exists libusb-1.0 || die "libusb-1.0 still not found"
  fi
  case "$LANG_SEL" in
    pt) echo "Obs.: se o Mac não detectar o aparelho em FEL, use um hub USB entre o cabo e o computador.";;
    *)  echo "Note: if the Mac does not detect the device in FEL mode, put a USB hub between the cable and the computer.";;
  esac
}

parse_args "$@"
main_flow
