#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/ide.sh"

OS="$(devenv_os)"

vscode_user_settings_path() {
  case "$OS" in
    mac)   printf '%s\n' "$HOME/Library/Application Support/Code/User/settings.json" ;;
    *)     printf '%s\n' "$HOME/.config/Code/User/settings.json" ;;
  esac
}
cursor_user_settings_path() {
  case "$OS" in
    mac)   printf '%s\n' "$HOME/Library/Application Support/Cursor/User/settings.json" ;;
    *)     printf '%s\n' "$HOME/.config/Cursor/User/settings.json" ;;
  esac
}

install_vscode() {
  [ "${DEVENV_SKIP_CODE_INSTALL:-0}" = "1" ] && { log_info "VS Code install skipped (DEVENV_SKIP_CODE_INSTALL=1)"; return 0; }
  if command -v code >/dev/null 2>&1; then log_info "VS Code already installed"; return 0; fi
  case "$OS" in
    mac)        brew install --cask visual-studio-code ;;
    linux|wsl)
      log_warn "VS Code not on PATH. Install from https://code.visualstudio.com/download (apt: deb from packages.microsoft.com)."
      ;;
  esac
}

install_cursor() {
  [ "${DEVENV_SKIP_CODE_INSTALL:-0}" = "1" ] && { log_info "Cursor install skipped (DEVENV_SKIP_CODE_INSTALL=1)"; return 0; }
  if command -v cursor >/dev/null 2>&1; then log_info "Cursor already installed"; return 0; fi
  case "$OS" in
    mac)        brew install --cask cursor ;;
    linux|wsl)
      log_warn "Cursor not on PATH. Download from https://cursor.com/downloads"
      ;;
  esac
}

apply_vscode() {
  local ext_file="${DEVENV_VSCODE_EXT_FILE:-$ROOT/config/ide/vscode-extensions.txt}"
  local overlay="$ROOT/config/ide/vscode-settings.json"
  devenv_ide_install_extensions code "$ext_file"
  [ -f "$overlay" ] && devenv_ide_merge_settings "$overlay" "$(vscode_user_settings_path)"
  log_info "VS Code config applied"
}

apply_cursor() {
  local ext_file="${DEVENV_CURSOR_EXT_FILE:-$ROOT/config/ide/cursor-extensions.txt}"
  local overlay="$ROOT/config/ide/cursor-settings.json"
  devenv_ide_install_extensions cursor "$ext_file"
  [ -f "$overlay" ] && devenv_ide_merge_settings "$overlay" "$(cursor_user_settings_path)"
  log_info "Cursor config applied"
}

install_vscode
install_cursor
apply_vscode
apply_cursor
log_info "50-ide: done"
