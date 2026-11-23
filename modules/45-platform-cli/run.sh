#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/versions.sh"

KUBECTL_REPO_MINOR="$(devenv_tool_get kubectl version)"

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
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian) install_kubectl_apt ;;
    linux:fedora|linux:rhel|linux:centos|wsl:fedora|wsl:rhel|wsl:centos) install_kubectl_dnf ;;
    linux:arch|linux:manjaro|wsl:arch|wsl:manjaro) sudo pacman -S --needed --noconfirm kubectl ;;
    *) log_err "Unsupported OS/distro for kubectl: $(devenv_os)/$(devenv_distro)"; return 1 ;;
  esac
  if ! command -v kubectl >/dev/null 2>&1 || ! kubectl version --client >/dev/null 2>&1; then
    log_err "kubectl installation completed but 'kubectl version --client' is unavailable."
    return 1
  fi
  log_info 'kubectl installed'
}

install_kubectl_apt() {
  sudo apt-get update -qq
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_REPO_MINOR}/deb/Release.key" |
    sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBECTL_REPO_MINOR}/deb/ /" |
    sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
  sudo apt-get update -qq
  sudo apt-get install -y kubectl
}

install_kubectl_dnf() {
  printf '%s\n' \
    '[kubernetes]' \
    'name=Kubernetes' \
    "baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBECTL_REPO_MINOR}/rpm/" \
    'enabled=1' \
    'gpgcheck=1' \
    "gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBECTL_REPO_MINOR}/rpm/repodata/repomd.xml.key" |
    sudo tee /etc/yum.repos.d/kubernetes.repo >/dev/null
  sudo dnf install -y kubectl
}

install_helm() {
  [ "${DEVENV_PLATFORM_HELM:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_HELM_INSTALL:-0}" = "1" ]; then log_info 'Helm install skipped (DEVENV_SKIP_HELM_INSTALL)'; return 0; fi
  if command -v helm >/dev/null 2>&1; then log_info "Helm $(helm version --short 2>/dev/null) already installed"; return 0; fi
  case "$(devenv_os):$(devenv_distro)" in
    mac:*) brew install helm ;;
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian)
      install_helm_apt
      ;;
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

install_helm_apt() (
  local key key_id tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  key="$tmp_dir/helm.asc"
  key_id='DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6'
  sudo apt-get update -qq
  sudo apt-get install -y curl gpg
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "$key"
  if [ "$(gpg --batch --import-options=show-only --with-colons "$key" | awk -F: '$1 == "fpr" {print $10; exit}')" != "$key_id" ]; then
    log_err 'Unexpected Helm apt key fingerprint'
    return 1
  fi
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo install -m 0644 "$key" /etc/apt/keyrings/helm.asc
  printf '%s\n' \
    'Types: deb' \
    'URIs: https://packages.buildkite.com/helm-linux/helm-debian/any/' \
    'Suites: any' \
    'Components: main' \
    'Signed-By: /etc/apt/keyrings/helm.asc' |
    sudo tee /etc/apt/sources.list.d/helm-stable-debian.sources >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y helm
)

install_opentofu() {
  [ "${DEVENV_PLATFORM_OPENTOFU:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_OPENTOFU_INSTALL:-0}" = "1" ]; then log_info 'OpenTofu install skipped (DEVENV_SKIP_OPENTOFU_INSTALL)'; return 0; fi
  if command -v tofu >/dev/null 2>&1; then log_info "OpenTofu $(tofu version 2>/dev/null | head -n1) already installed"; return 0; fi
  case "$(devenv_os):$(devenv_distro)" in
    mac:*) brew install opentofu ;;
    linux:ubuntu|linux:debian|wsl:ubuntu|wsl:debian)
      sudo apt-get update -qq && sudo apt-get install -y ca-certificates curl gnupg
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://get.opentofu.org/opentofu.gpg | sudo tee /etc/apt/keyrings/opentofu.gpg >/dev/null
      curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey |
        sudo gpg --no-tty --batch --yes --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg
      sudo chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg
      printf '%s\n' \
        'deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main' \
        'deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main' |
        sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null
      sudo chmod a+r /etc/apt/sources.list.d/opentofu.list
      sudo apt-get update -qq && sudo apt-get install -y tofu ;;
    linux:fedora|linux:rhel|linux:centos|wsl:fedora|wsl:rhel|wsl:centos)
      printf '%s\n' \
        '[opentofu]' \
        'name=opentofu' \
        "baseurl=https://packages.opentofu.org/opentofu/tofu/rpm_any/rpm_any/\$basearch" \
        'repo_gpgcheck=0' \
        'gpgcheck=1' \
        'enabled=1' \
        'gpgkey=https://get.opentofu.org/opentofu.gpg' \
        '       https://packages.opentofu.org/opentofu/tofu/gpgkey' \
        'sslverify=1' \
        'sslcacert=/etc/pki/tls/certs/ca-bundle.crt' \
        'metadata_expire=300' |
        sudo tee /etc/yum.repos.d/opentofu.repo >/dev/null
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
