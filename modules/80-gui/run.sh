#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/gui.sh"

if ! devenv_gui_enabled; then
  log_info "80-gui: opt-in, skipped (set DEVENV_GUI_ENABLED=1 to enable)"
  exit 0
fi

if [ "${DEVENV_SKIP_GUI_INSTALL:-0}" = "1" ]; then
  log_info "80-gui: skipped (DEVENV_SKIP_GUI_INSTALL=1)"
  exit 0
fi

brewfile="${DEVENV_GUI_BREWFILE:-$ROOT/config/gui/Brewfile}"

OS="$(devenv_os)"
case "$OS" in
  mac|linux|wsl)
    devenv_gui_brew_bundle "$brewfile"
    ;;
  windows)
    # bash on Windows (git-bash/MSYS); use winget via run.ps1 in normal flow.
    # If brew happens to be on PATH (e.g. tests), honour it.
    if command -v brew >/dev/null 2>&1; then
      devenv_gui_brew_bundle "$brewfile"
    else
      log_info "80-gui: windows uses winget (see run.ps1); nothing to do here"
    fi
    ;;
  *)
    log_info "80-gui: $OS has no GUI runner; nothing to do"
    ;;
esac

log_info "80-gui: done"
