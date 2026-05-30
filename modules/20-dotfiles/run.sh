#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

REMOTE="${DOTFILES_REMOTE:-git@github.com:duthaho/dotfiles.git}"
HTTPS_FALLBACK="https://github.com/duthaho/dotfiles.git"
DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

clone_or_pull() {
  if [ -d "$DIR/.git" ]; then
    log_info "Updating $DIR"
    git -C "$DIR" fetch --quiet
    git -C "$DIR" pull --ff-only
    return 0
  fi
  log_info "Cloning $REMOTE -> $DIR"
  if ! git clone "$REMOTE" "$DIR" 2>/dev/null; then
    log_warn "SSH clone failed; falling back to HTTPS"
    git clone "$HTTPS_FALLBACK" "$DIR"
  fi
}

run_dotfiles_bootstrap() {
  local os
  os="$(devenv_os)"
  case "$os" in
    mac|linux|wsl)
      if [ ! -x "$DIR/bootstrap.sh" ]; then
        log_err "$DIR/bootstrap.sh missing or not executable"
        return 1
      fi
      log_info "Running $DIR/bootstrap.sh --non-interactive"
      ( cd "$DIR" && ./bootstrap.sh --non-interactive )
      ;;
    windows)
      if [ ! -f "$DIR/bootstrap.ps1" ]; then
        log_err "$DIR/bootstrap.ps1 missing"
        return 1
      fi
      log_info "Running $DIR/bootstrap.ps1 -NonInteractive"
      ( cd "$DIR" && pwsh -NoProfile -File ./bootstrap.ps1 -NonInteractive )
      ;;
  esac
}

clone_or_pull
run_dotfiles_bootstrap
log_info "20-dotfiles: done"
