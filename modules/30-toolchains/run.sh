#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

OS="$(devenv_os)"

install_mise() {
  if command -v mise >/dev/null 2>&1; then
    log_info "mise $(mise --version) already installed"
    return 0
  fi
  log_info "Installing mise"
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
}

install_devbox() {
  case "$OS" in
    windows)
      log_warn "devbox skipped on native Windows (requires Nix; use WSL for devbox-managed envs)"
      return 0
      ;;
  esac
  if command -v devbox >/dev/null 2>&1; then
    log_info "devbox $(devbox version 2>/dev/null | head -n1) already installed"
    return 0
  fi
  log_info "Installing devbox"
  curl -fsSL https://get.jetify.com/devbox | bash -s -- -f
}

install_direnv() {
  if command -v direnv >/dev/null 2>&1; then
    log_info "direnv $(direnv --version) already installed"
    return 0
  fi
  case "$OS" in
    mac) brew install direnv ;;
    linux|wsl)
      local distro
      distro="$(devenv_distro)"
      case "$distro" in
        ubuntu|debian)    sudo apt-get update -qq && sudo apt-get install -y direnv ;;
        fedora|rhel|centos) sudo dnf install -y direnv ;;
        arch|manjaro)     sudo pacman -S --needed --noconfirm direnv ;;
        *) log_warn "Distro $distro: install direnv manually"; return 1 ;;
      esac
      ;;
  esac
}

write_mise_config() {
  local cfg="$HOME/.config/mise/config.toml"
  if [ -f "$cfg" ]; then
    log_info "mise config already at $cfg (left alone)"
    return 0
  fi
  mkdir -p "$(dirname "$cfg")"
  if [ "${DEVENV_LANGS_SET:-0}" = "1" ]; then
    # The menu chose a language subset (possibly empty). Keep only the [tools]
    # lines whose key is in DEVENV_LANGS; other sections (comments, [settings])
    # pass through untouched.
    awk -v langs=",${DEVENV_LANGS}," '
      /^\[tools\]/ { intools = 1; print; next }
      /^\[/        { intools = 0; print; next }
      {
        if (intools && $0 ~ /=/) {
          key = $0
          sub(/[[:space:]]*=.*$/, "", key)
          gsub(/[[:space:]]/, "", key)
          if (key != "" && index(langs, "," key ",") == 0) next
        }
        print
      }
    ' "$HERE/mise.config.toml" > "$cfg"
    log_info "Wrote $cfg (languages: $DEVENV_LANGS)"
  else
    cp "$HERE/mise.config.toml" "$cfg"
    log_info "Wrote $cfg"
  fi
}

write_direnv_lib() {
  local lib_dir="$HOME/.config/direnv/lib"
  mkdir -p "$lib_dir"
  cat > "$lib_dir/use_mise.sh" <<'EOF'
use_mise() { eval "$(mise env --shell bash)"; }
EOF
  log_info "Wrote $lib_dir/use_mise.sh"
}

install_mise
install_devbox
install_direnv
write_mise_config
write_direnv_lib
log_info "30-toolchains: done"
