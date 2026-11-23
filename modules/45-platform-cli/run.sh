#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

if [ "${DEVENV_SKIP_PLATFORM_CLI_INSTALL:-0}" = "1" ]; then
  log_info '45-platform-cli skipped (DEVENV_SKIP_PLATFORM_CLI_INSTALL)'
  exit 0
fi

install_kubectl() {
  [ "${DEVENV_PLATFORM_KUBECTL:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_KUBECTL_INSTALL:-0}" = "1" ]; then log_info 'kubectl install skipped (DEVENV_SKIP_KUBECTL_INSTALL)'; return 0; fi
  if command -v kubectl >/dev/null 2>&1; then log_info "kubectl $(kubectl version --client --output=yaml 2>/dev/null | awk '/gitVersion:/ {print $2; exit}') already installed"; return 0; fi
  case "$(devenv_os):$(devenv_distro)" in
    mac:*) brew install kubectl ;;
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian) sudo apt-get update -qq && sudo apt-get install -y kubernetes-client ;;
    linux:fedora|linux:rhel|linux:centos|wsl:fedora|wsl:rhel|wsl:centos) sudo dnf install -y kubernetes-client ;;
    linux:arch|linux:manjaro|wsl:arch|wsl:manjaro) sudo pacman -S --needed --noconfirm kubectl ;;
    *) log_err "Unsupported OS/distro for kubectl: $(devenv_os)/$(devenv_distro)"; return 1 ;;
  esac
  if ! command -v kubectl >/dev/null 2>&1 || ! kubectl version --client >/dev/null 2>&1; then
    log_err "kubectl installation completed but 'kubectl version --client' is unavailable."
    return 1
  fi
  log_info 'kubectl installed'
}

install_helm() {
  [ "${DEVENV_PLATFORM_HELM:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_HELM_INSTALL:-0}" = "1" ]; then log_info 'Helm install skipped (DEVENV_SKIP_HELM_INSTALL)'; return 0; fi
  if command -v helm >/dev/null 2>&1; then log_info "Helm $(helm version --short 2>/dev/null) already installed"; return 0; fi
  case "$(devenv_os):$(devenv_distro)" in
    mac:*) brew install helm ;;
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian)
      curl -fsSL https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
      sudo apt-get update -qq && sudo apt-get install -y apt-transport-https
      echo 'deb [arch='"$(dpkg --print-architecture)"' signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y helm ;;
    linux:fedora|linux:rhel|linux:centos|wsl:fedora|wsl:rhel|wsl:centos)
      sudo dnf install -y helm ;;
    linux:arch|linux:manjaro|wsl:arch|wsl:manjaro) sudo pacman -S --needed --noconfirm helm ;;
    *) log_err "Unsupported OS/distro for Helm: $(devenv_os)/$(devenv_distro)"; return 1 ;;
  esac
  if ! command -v helm >/dev/null 2>&1 || ! helm version --short >/dev/null 2>&1; then
    log_err "Helm installation completed but 'helm version --short' is unavailable."
    return 1
  fi
  log_info 'Helm installed'
}

install_opentofu() {
  [ "${DEVENV_PLATFORM_OPENTOFU:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_OPENTOFU_INSTALL:-0}" = "1" ]; then log_info 'OpenTofu install skipped (DEVENV_SKIP_OPENTOFU_INSTALL)'; return 0; fi
  if command -v tofu >/dev/null 2>&1; then log_info "OpenTofu $(tofu version 2>/dev/null | head -n1) already installed"; return 0; fi
  case "$(devenv_os):$(devenv_distro)" in
    mac:*) brew install opentofu ;;
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian)
      curl -fsSL https://get.opentofu.org/opentofu.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/opentofu.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/opentofu.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y tofu ;;
    linux:fedora|linux:rhel|linux:centos|wsl:fedora|wsl:rhel|wsl:centos)
      sudo dnf config-manager --add-repo https://get.opentofu.org/tofu.repo
      sudo dnf install -y tofu ;;
    linux:arch|linux:manjaro|wsl:arch|wsl:manjaro) sudo pacman -S --needed --noconfirm opentofu ;;
    *) log_err "Unsupported OS/distro for OpenTofu: $(devenv_os)/$(devenv_distro)"; return 1 ;;
  esac
  if ! command -v tofu >/dev/null 2>&1 || ! tofu version >/dev/null 2>&1; then
    log_err "OpenTofu installation completed but 'tofu version' is unavailable."
    return 1
  fi
  log_info 'OpenTofu installed'
}

if [ "${DEVENV_PLATFORM_KUBECTL:-0}" != "1" ] && [ "${DEVENV_PLATFORM_HELM:-0}" != "1" ] && [ "${DEVENV_PLATFORM_OPENTOFU:-0}" != "1" ]; then
  log_info '45-platform-cli skipped (select platform CLIs in the menu or set DEVENV_PLATFORM_KUBECTL=1 / DEVENV_PLATFORM_HELM=1 / DEVENV_PLATFORM_OPENTOFU=1)'
  exit 0
fi

install_kubectl
install_helm
install_opentofu
log_info '45-platform-cli: done'
