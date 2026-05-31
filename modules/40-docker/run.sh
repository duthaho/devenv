#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/docker.sh"

OS="$(devenv_os)"

install_mac() {
  if [ -d '/Applications/Docker.app' ] || command -v docker >/dev/null 2>&1; then
    log_info "Docker already present"
    return 0
  fi
  log_info "brew install --cask docker"
  brew install --cask docker
  log_warn "Open Docker Desktop once to start the engine, then re-run devenv up."
}

install_linux() {
  if command -v docker >/dev/null 2>&1; then
    log_info "Docker already installed"
  else
    log_info "Installing Docker via get.docker.com"
    curl -fsSL https://get.docker.com | sudo sh
  fi
  if ! getent group docker | grep -q "\b$USER\b"; then
    log_info "Adding $USER to docker group"
    sudo usermod -aG docker "$USER"
    log_warn "Log out and back in for group membership to take effect."
  fi
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now docker || true
  fi
}

install_wsl() {
  # WSL users typically use Docker Desktop on the Windows host (integrated into WSL).
  if command -v docker >/dev/null 2>&1; then
    log_info "Docker reachable from WSL (likely via Docker Desktop integration)"
    return 0
  fi
  log_warn "Docker not found in WSL. Recommended: install Docker Desktop on the Windows host"
  log_warn "  and enable WSL integration in Settings -> Resources -> WSL Integration."
  log_warn "Alternative: 'curl -fsSL https://get.docker.com | sudo sh' inside WSL (no Desktop)."
  return 1
}

case "$OS" in
  mac)     install_mac ;;
  linux)   install_linux ;;
  wsl)     install_wsl ;;
  windows) log_err "40-docker on Windows uses run.ps1, not run.sh"; exit 2 ;;
esac

# Wait briefly for the engine to be reachable (Docker Desktop on mac may need a moment).
for _ in 1 2 3 4 5 6 7 8 9 10; do
  docker info >/dev/null 2>&1 && break
  sleep 2
done

if ! docker info >/dev/null 2>&1; then
  log_err "Docker engine not reachable. Start Docker Desktop / docker daemon and re-run."
  exit 1
fi

if ! docker network inspect devenv >/dev/null 2>&1; then
  log_info "Creating Docker network: devenv"
  docker network create devenv
else
  log_info "Docker network 'devenv' already exists"
fi

# Sanity-check compose v2.
if ! docker compose version >/dev/null 2>&1; then
  log_err "'docker compose' (v2) not available. Install the compose plugin."
  exit 1
fi

# Optional autostart of the default profile.
if [ "${DEVENV_SERVICES_AUTOSTART:-1}" = "1" ]; then
  log_info "Starting baseline services (profile: default)"
  # shellcheck disable=SC2046
  docker compose $(devenv_compose_args) --profile default up -d
else
  log_info "Autostart disabled (DEVENV_SERVICES_AUTOSTART=0); run 'devenv services up' when ready."
fi

log_info "40-docker: done"
