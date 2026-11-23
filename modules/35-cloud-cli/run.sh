#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

install_wrangler() {
  [ "${DEVENV_CLOUD_WRANGLER:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_NPM_INSTALL:-0}" = "1" ] || [ "${DEVENV_SKIP_WRANGLER_INSTALL:-0}" = "1" ]; then
    log_info 'wrangler install skipped (DEVENV_SKIP_NPM_INSTALL or DEVENV_SKIP_WRANGLER_INSTALL)'
    return 0
  fi
  if command -v wrangler >/dev/null 2>&1; then
    log_info "wrangler $(wrangler --version 2>/dev/null | head -n1) already installed"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log_warn 'Node/npm not on PATH; install Node via 30-toolchains, then re-run --force --only 35-cloud-cli.'
    return 0
  fi
  log_info 'npm install -g wrangler'
  npm install -g wrangler >/dev/null
  if ! command -v wrangler >/dev/null 2>&1 || ! wrangler --version >/dev/null 2>&1; then
    log_err "Wrangler installation completed but 'wrangler --version' is unavailable. Restart the shell to refresh mise shims, then re-run --force --only 35-cloud-cli."
    return 1
  fi
  log_info "wrangler $(wrangler --version | head -n1) installed"
}

install_cloudflared_apt() {
  log_info 'Adding official Cloudflare apt repository for cloudflared'
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-ascii-pgp.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloudflare-main.gpg
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y cloudflared
}

install_cloudflared() {
  [ "${DEVENV_CLOUD_CLOUDFLARED:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_CLOUDFLARED_INSTALL:-0}" = "1" ]; then
    log_info 'cloudflared install skipped (DEVENV_SKIP_CLOUDFLARED_INSTALL)'
    return 0
  fi
  if command -v cloudflared >/dev/null 2>&1; then
    log_info "cloudflared $(cloudflared --version 2>/dev/null | head -n1) already installed"
    return 0
  fi

  case "$(devenv_os)" in
    mac)
      log_info 'brew install cloudflared'
      brew install cloudflared
      ;;
    linux|wsl)
      case "$(devenv_distro)" in
        ubuntu|debian) install_cloudflared_apt ;;
        fedora|rhel|centos)
          log_info 'Adding official Cloudflare dnf repository for cloudflared'
          sudo dnf config-manager --add-repo https://pkg.cloudflare.com/cloudflared-ascii.repo
          sudo dnf install -y cloudflared
          ;;
        arch|manjaro)
          log_info 'pacman: install cloudflared'
          sudo pacman -S --needed --noconfirm cloudflared
          ;;
        *) log_err "Unsupported Linux distro for cloudflared: $(devenv_distro)"; return 1 ;;
      esac
      ;;
    *) log_err 'cloudflared installation is only supported on macOS and Linux from run.sh'; return 1 ;;
  esac
  if ! command -v cloudflared >/dev/null 2>&1 || ! cloudflared --version >/dev/null 2>&1; then
    log_err "cloudflared installation completed but 'cloudflared --version' is unavailable."
    return 1
  fi
  log_info "cloudflared $(cloudflared --version | head -n1) installed"
}

if [ "${DEVENV_CLOUD_WRANGLER:-0}" != "1" ] && [ "${DEVENV_CLOUD_CLOUDFLARED:-0}" != "1" ]; then
  log_info '35-cloud-cli skipped (select Cloudflare CLIs in the menu or set DEVENV_CLOUD_WRANGLER=1 / DEVENV_CLOUD_CLOUDFLARED=1)'
  exit 0
fi

install_wrangler
install_cloudflared
log_info '35-cloud-cli: done'
