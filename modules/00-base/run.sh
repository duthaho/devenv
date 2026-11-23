#!/usr/bin/env bash
set -euo pipefail
# 00-base: bootstrap package managers + minimal CLI cluster.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

OS="$(devenv_os)"

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    log_info "Homebrew already installed"
    return 0
  fi
  log_info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

brew_install_if_missing() {
  local pkg
  for pkg in "$@"; do
    if brew list --formula --versions "$pkg" >/dev/null 2>&1; then
      log_info "brew already has $pkg"
    else
      log_info "brew install $pkg"
      brew install "$pkg"
    fi
  done
}

apt_install() {
  log_info "apt: install ${*}"
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends "$@"
}

apt_install_gum() {
  if command -v gum >/dev/null 2>&1; then
    log_info "gum already installed"
    return 0
  fi
  log_info "Adding Charm apt repo for gum"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
    | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gum
}

apt_install_gh() {
  if command -v gh >/dev/null 2>&1 && [ "${DEVENV_FORCE_GH_INSTALL:-}" != "1" ]; then
    log_info "gh already installed"
    return 0
  fi
  log_info "Adding official GitHub CLI apt repository"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
}

install_shell_productivity_apt() {
  if [ "${DEVENV_SKIP_SHELL_PRODUCTIVITY:-}" = "1" ]; then
    log_info "Skipping shell productivity tools (DEVENV_SKIP_SHELL_PRODUCTIVITY=1)"
    return 0
  fi
  apt_install fzf ripgrep bat zoxide
  # Debian and Ubuntu package bat as batcat. Keep the cross-platform command
  # name stable without modifying the distro-owned /usr/bin directory.
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    log_info "Linking /usr/local/bin/bat to batcat"
    sudo ln -sfn "$(command -v batcat)" /usr/local/bin/bat
  fi
}

install_shell_productivity_brew() {
  [ "${DEVENV_SKIP_SHELL_PRODUCTIVITY:-}" = "1" ] && {
    log_info "Skipping shell productivity tools (DEVENV_SKIP_SHELL_PRODUCTIVITY=1)"
    return 0
  }
  brew_install_if_missing fzf ripgrep bat zoxide
}

run_mac() {
  ensure_brew
  brew_install_if_missing jq gum gh
  install_shell_productivity_brew
}

run_linux() {
  local distro
  distro="$(devenv_distro)"
  case "$distro" in
    ubuntu|debian)
      apt_install curl git jq
      apt_install_gum
      apt_install_gh
      install_shell_productivity_apt
      ;;
    fedora|rhel|centos)
      log_info "dnf: install curl git jq"
      sudo dnf install -y curl git jq
      if ! command -v gh >/dev/null 2>&1 || [ "${DEVENV_FORCE_GH_INSTALL:-}" = "1" ]; then
        log_info "Adding official GitHub CLI dnf repository"
        sudo dnf install -y 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install -y gh --repo gh-cli
      fi
      if ! command -v gum >/dev/null 2>&1; then
        log_info "Adding Charm dnf repo for gum"
        sudo tee /etc/yum.repos.d/charm.repo >/dev/null <<'EOF'
[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key
EOF
        sudo dnf install -y gum
      fi
      if [ "${DEVENV_SKIP_SHELL_PRODUCTIVITY:-}" != "1" ]; then
        sudo dnf install -y fzf ripgrep bat zoxide
      else
        log_info "Skipping shell productivity tools (DEVENV_SKIP_SHELL_PRODUCTIVITY=1)"
      fi
      ;;
    arch|manjaro)
      log_info "pacman: install curl git jq gum gh"
      sudo pacman -S --needed --noconfirm curl git jq gum gh
      if [ "${DEVENV_SKIP_SHELL_PRODUCTIVITY:-}" != "1" ]; then
        sudo pacman -S --needed --noconfirm fzf ripgrep bat zoxide
      else
        log_info "Skipping shell productivity tools (DEVENV_SKIP_SHELL_PRODUCTIVITY=1)"
      fi
      ;;
    *)
      log_err "Unsupported Linux distro: $distro"
      return 1
      ;;
  esac
}

run_windows() {
  if ! command -v winget >/dev/null 2>&1; then
    log_err "winget is required on Windows. Install 'App Installer' from the Microsoft Store."
    return 1
  fi
  local pkg
  for pkg in Git.Git GitHub.cli stedolan.jq charmbracelet.gum; do
    log_info "winget install $pkg"
    winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id "$pkg" || true
  done
  if [ "${DEVENV_SKIP_SHELL_PRODUCTIVITY:-}" = "1" ]; then
    log_info "Skipping shell productivity tools (DEVENV_SKIP_SHELL_PRODUCTIVITY=1)"
    return 0
  fi
  for pkg in junegunn.fzf BurntSushi.ripgrep.MSVC sharkdp.bat ajeetdsouza.zoxide; do
    log_info "winget install $pkg"
    winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id "$pkg" || true
  done
}

case "$OS" in
  mac)        run_mac ;;
  linux|wsl)  run_linux ;;
  windows)    run_windows ;;
  *)          log_err "Unsupported OS: $OS"; exit 1 ;;
esac

if ! gh --version >/dev/null 2>&1; then
  log_err "gh was not available after installation"
  exit 1
fi

log_info "00-base: done"
