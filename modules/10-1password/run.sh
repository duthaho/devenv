#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/op.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/prompts.sh"

OS="$(devenv_os)"

install_mac() {
  if ! brew list --cask 1password >/dev/null 2>&1; then
    log_info "brew install --cask 1password"
    brew install --cask 1password
  else
    log_info "1Password desktop already installed"
  fi
  if ! command -v op >/dev/null 2>&1; then
    log_info "brew install 1password-cli"
    brew install 1password-cli
  else
    log_info "op CLI already installed"
  fi
}

install_linux() {
  local distro
  distro="$(devenv_distro)"
  case "$distro" in
    ubuntu|debian)
      if ! command -v op >/dev/null 2>&1; then
        local arch
        arch="$(dpkg --print-architecture)"
        case "$arch" in
          amd64|arm64) ;;
          *) log_err "1Password CLI: unsupported arch '$arch' (need amd64 or arm64)"; return 1 ;;
        esac
        log_info "Adding 1Password apt repo ($arch, CLI only)"
        curl -sS https://downloads.1password.com/linux/keys/1password.asc \
          | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo "deb [arch=$arch signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$arch stable main" \
          | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y 1password-cli
      else
        log_info "op CLI already installed"
      fi
      ;;
    fedora|rhel|centos)
      if ! command -v op >/dev/null 2>&1; then
        log_info "Adding 1Password yum repo (CLI only)"
        sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
        sudo sh -c 'cat > /etc/yum.repos.d/1password.repo <<EOF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF'
        sudo dnf install -y 1password-cli
      else
        log_info "op CLI already installed"
      fi
      ;;
    arch|manjaro)
      if ! command -v op >/dev/null 2>&1; then
        log_warn "Install 1password-cli from AUR (e.g., yay -S 1password-cli) then re-run."
        return 1
      fi
      ;;
    *)
      log_warn "Distro $distro: please install 1password-cli manually and re-run."
      return 1
      ;;
  esac
}

install_windows() {
  if ! command -v op >/dev/null 2>&1; then
    log_info "winget install AgileBits.1Password.CLI"
    winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id AgileBits.1Password.CLI || true
  fi
  if ! powershell.exe -Command "Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object DisplayName -like '1Password*'" 2>/dev/null | grep -qi 1password; then
    log_info "winget install 1Password (desktop)"
    winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id AgileBits.1Password || true
  fi
}

case "$OS" in
  mac)        install_mac ;;
  linux|wsl)  install_linux ;;
  windows)    install_windows ;;
  *)          log_err "Unsupported OS: $OS"; exit 1 ;;
esac

if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  log_info "OP_SERVICE_ACCOUNT_TOKEN detected; skipping interactive signin"
elif op_signed_in; then
  log_info "1Password CLI already signed in"
else
  case "$OS" in
    mac|windows)
      log_info ""
      log_info "============================================================"
      log_info "Manual step: open the 1Password desktop app and"
      log_info "  1) Sign in to your account."
      log_info "  2) Settings -> Developer -> 'Integrate with 1Password CLI'  [x]"
      log_info "  3) Settings -> Developer -> 'Use the SSH agent'              [x]"
      log_info "============================================================"
      if prompt_confirm "Ready to verify (op whoami)?"; then
        op whoami >/dev/null 2>&1 || true
      fi
      ;;
    linux|wsl)
      log_info ""
      log_info "============================================================"
      log_info "1Password CLI signin (CLI-only mode — no desktop app)"
      log_info ""
      log_info "  For future shells, add to your shell profile:"
      log_info '    eval "$(op signin)"'
      log_info ""
      log_info "  For unattended/CI, export OP_SERVICE_ACCOUNT_TOKEN before"
      log_info "  running devenv. See https://developer.1password.com/docs/service-accounts/"
      log_info "============================================================"
      if prompt_confirm "Sign in interactively now?"; then
        # shellcheck disable=SC2046
        if eval "$(op signin 2>/dev/null || true)" 2>/dev/null && op whoami >/dev/null 2>&1; then
          log_info "Signed in for the duration of this bootstrap."
        else
          log_warn "Interactive signin failed or skipped."
          log_warn "Re-run with OP_SERVICE_ACCOUNT_TOKEN exported, or run \`eval \"\$(op signin)\"\` and re-invoke devenv."
        fi
      fi
      ;;
  esac
fi

case "$OS" in
  mac)     AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ;;
  windows) AGENT_SOCK="\\\\.\\pipe\\openssh-ssh-agent" ;;
  *)       AGENT_SOCK="" ;;
esac

if [ -n "$AGENT_SOCK" ]; then
  mkdir -p "$HOME/.ssh/config.d"
  cat > "$HOME/.ssh/config.d/10-1password.conf" <<EOF
# Managed by devenv module 10-1password. Do not edit by hand.
Host *
  IdentityAgent "$AGENT_SOCK"
EOF
  chmod 600 "$HOME/.ssh/config.d/10-1password.conf"

  SSH_CONFIG="$HOME/.ssh/config"
  INCLUDE_LINE='Include ~/.ssh/config.d/*.conf'
  if [ ! -f "$SSH_CONFIG" ] || ! grep -Fxq "$INCLUDE_LINE" "$SSH_CONFIG"; then
    log_info "Adding '$INCLUDE_LINE' to $SSH_CONFIG"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    { echo "$INCLUDE_LINE"; [ -f "$SSH_CONFIG" ] && cat "$SSH_CONFIG"; } > "$SSH_CONFIG.new"
    mv "$SSH_CONFIG.new" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
  fi
else
  log_info "No 1Password SSH agent on this OS (no desktop app); SSH config snippet skipped."
  case "$OS" in
    wsl)
      log_info "  WSL: see https://developer.1password.com/docs/ssh/agent/wsl/ to bridge to the Windows agent."
      ;;
    linux)
      log_info "  Linux server: use 'op read' to retrieve keys at use time, or load keys into ssh-agent manually."
      ;;
  esac
fi

whoami_line="$(op whoami 2>/dev/null | head -n1 || echo 'not-signed-in')"
log_info "10-1password: done. Auth state: $whoami_line"
