#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
. "$ROOT/lib/versions.sh"

install_wrangler() {
  [ "${DEVENV_CLOUD_WRANGLER:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_NPM_INSTALL:-0}" = "1" ] || [ "${DEVENV_SKIP_WRANGLER_INSTALL:-0}" = "1" ]; then
    log_info 'wrangler install skipped (DEVENV_SKIP_NPM_INSTALL or DEVENV_SKIP_WRANGLER_INSTALL)'
    return 0
  fi
  if command -v wrangler >/dev/null 2>&1; then
    local installed drift
    installed="$(wrangler --version 2>/dev/null | head -n1)"
    drift="$(devenv_tool_drift wrangler "$installed")"
    [ -z "$drift" ] || log_warn "wrangler $installed; manifest $drift; run: npm install -g $(devenv_npm_spec wrangler)"
    log_info "wrangler $installed already installed"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log_warn 'Node/npm not on PATH; install Node via 30-toolchains, then re-run --force --only 35-cloud-cli.'
    return 0
  fi
  local spec
  spec="$(devenv_npm_spec wrangler)"
  log_info "npm install -g $spec"
  npm install -g "$spec" >/dev/null
  if ! command -v wrangler >/dev/null 2>&1 || ! wrangler --version >/dev/null 2>&1; then
    log_err "Wrangler installation completed but 'wrangler --version' is unavailable. Restart the shell to refresh mise shims, then re-run --force --only 35-cloud-cli."
    return 1
  fi
  drift="$(devenv_tool_drift wrangler "$(wrangler --version 2>/dev/null | head -n1)")"
  [ -z "$drift" ] || { log_err "wrangler version mismatch: $drift"; return 1; }
  log_info "wrangler $(wrangler --version | head -n1) installed"
}

install_cloudflared_apt() {
  log_info 'Adding official Cloudflare apt repository for cloudflared'
  sudo install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
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

aws_cli_version() {
  command -v aws >/dev/null 2>&1 || return 1
  aws --version 2>&1 | head -n1
}

install_aws_cli_linux() (
  local arch archive signature gpg_home tmp_dir tool url
  tmp_dir=""
  trap '[ -z "$tmp_dir" ] || rm -rf "$tmp_dir"' EXIT
  case "$(uname -m)" in
    x86_64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) log_err "Unsupported Linux architecture for AWS CLI v2: $(uname -m)"; return 1 ;;
  esac
  for tool in curl gpg unzip; do
    command -v "$tool" >/dev/null 2>&1 || { log_err "AWS CLI v2 needs $tool to verify and install the official bundle."; return 1; }
  done
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/awscliv2.zip"
  signature="$archive.sig"
  gpg_home="$tmp_dir/gnupg"
  mkdir -m 700 "$gpg_home"
  url="$(devenv_awscli_url "linux-${arch}")"
  log_info "Downloading official AWS CLI v2 bundle for ${arch}"
  curl -fsSL "$url" -o "$archive"
  devenv_verify_sha256 "$archive" awscli "linux-${arch}"
  curl -fsSL "${url}.sig" -o "$signature"
  gpg --batch --homedir "$gpg_home" --import "$HERE/aws-cli-public-key.asc" >/dev/null 2>&1
  gpg --batch --homedir "$gpg_home" --verify "$signature" "$archive"
  unzip -q "$archive" -d "$tmp_dir"
  sudo "$tmp_dir/aws/install" --update
)

install_aws_cli_macos() (
  local pkg pkg_dir
  pkg_dir=""
  trap '[ -z "$pkg_dir" ] || rm -rf "$pkg_dir"' EXIT
  pkg_dir="$(mktemp -d)"
  pkg="$pkg_dir/AWSCLIV2.pkg"
  log_info 'Downloading official AWS CLI v2 macOS package'
  curl -fsSL "$(devenv_awscli_url macos)" -o "$pkg"
  devenv_verify_sha256 "$pkg" awscli macos
  sudo installer -pkg "$pkg" -target /
)

install_aws_cli() {
  [ "${DEVENV_CLOUD_AWS:-0}" = "1" ] || return 0
  if [ "${DEVENV_SKIP_AWS_CLI_INSTALL:-0}" = "1" ]; then
    log_info 'AWS CLI install skipped (DEVENV_SKIP_AWS_CLI_INSTALL)'
    return 0
  fi
  local version
  if version="$(aws_cli_version)"; then
    if [[ "$version" == aws-cli/2.* ]]; then
      local drift
      drift="$(devenv_tool_drift awscli "$version")"
      [ -z "$drift" ] || log_warn "AWS CLI $version; manifest $drift; run: $(devenv_awscli_url linux-x86_64)"
      log_info "AWS CLI $version already installed"
      return 0
    fi
    log_warn "AWS CLI v1 detected ($version); not replacing it automatically. Remove v1, then re-run --force --only 35-cloud-cli."
    return 0
  fi
  case "$(devenv_os)" in
    mac) install_aws_cli_macos ;;
    linux|wsl) install_aws_cli_linux ;;
    *) log_err 'AWS CLI v2 installation is only supported on macOS and Linux from run.sh'; return 1 ;;
  esac
  if ! version="$(aws_cli_version)" || [[ "$version" != aws-cli/2.* ]]; then
    log_err "AWS CLI installation completed but 'aws --version' did not report v2."
    return 1
  fi
  drift="$(devenv_tool_drift awscli "$version")"
  [ -z "$drift" ] || { log_err "AWS CLI version mismatch: $drift"; return 1; }
  log_info "AWS CLI $version installed"
}

if [ "${DEVENV_CLOUD_WRANGLER:-0}" != "1" ] && [ "${DEVENV_CLOUD_CLOUDFLARED:-0}" != "1" ] && [ "${DEVENV_CLOUD_AWS:-0}" != "1" ]; then
  log_info '35-cloud-cli skipped (select cloud CLIs in the menu or set DEVENV_CLOUD_WRANGLER=1 / DEVENV_CLOUD_CLOUDFLARED=1 / DEVENV_CLOUD_AWS=1)'
  exit 0
fi

install_wrangler
install_cloudflared
install_aws_cli
log_info '35-cloud-cli: done'
