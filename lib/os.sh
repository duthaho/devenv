#!/usr/bin/env bash
# OS / distro detection. Source me; do not exec.

# DEVENV_ETC and DEVENV_PROC allow tests to override the file locations
# used for distro / WSL detection. Production code leaves them unset.

devenv_os() {
  local proc="${DEVENV_PROC:-/proc}"
  case "${OSTYPE:-}" in
    darwin*) echo mac; return 0 ;;
    msys*|cygwin*|win32*) echo windows; return 0 ;;
  esac
  if [ -r "$proc/version" ] && grep -qi microsoft "$proc/version" 2>/dev/null; then
    echo wsl; return 0
  fi
  case "${OSTYPE:-}" in
    linux*) echo linux; return 0 ;;
  esac
  case "$(uname -s 2>/dev/null)" in
    Linux*)  echo linux; return 0 ;;
    Darwin*) echo mac; return 0 ;;
    MINGW*|MSYS*|CYGWIN*) echo windows; return 0 ;;
  esac
  echo unknown
}

devenv_distro() {
  local os
  os="$(devenv_os)"
  [ "$os" != "linux" ] && [ "$os" != "wsl" ] && { echo ""; return 0; }
  local etc="${DEVENV_ETC:-/etc}"
  if [ -r "$etc/os-release" ]; then
    # shellcheck disable=SC1090,SC1091
    local id
    id="$(. "$etc/os-release" 2>/dev/null && echo "${ID:-unknown}")"
    case "$id" in
      ubuntu|debian|fedora|rhel|centos|arch|manjaro|alpine) echo "$id" ;;
      *) echo unknown ;;
    esac
  else
    echo unknown
  fi
}
