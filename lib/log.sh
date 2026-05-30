#!/usr/bin/env bash
# Leveled logging to stderr. Honors DEVENV_LOG_LEVEL (debug|info|warn|error).
# Source me; do not exec.

_devenv_log_level_num() {
  case "${1:-info}" in
    debug) echo 0 ;;
    info)  echo 1 ;;
    warn)  echo 2 ;;
    error) echo 3 ;;
    *)     echo 1 ;;
  esac
}

_devenv_log() {
  local lvl="$1"; shift
  local want have
  want=$(_devenv_log_level_num "${DEVENV_LOG_LEVEL:-info}")
  have=$(_devenv_log_level_num "$lvl")
  [ "$have" -lt "$want" ] && return 0
  local tag color reset=$'\033[0m'
  case "$lvl" in
    debug) tag="DEBUG"; color=$'\033[2m' ;;
    info)  tag="INFO " ; color=$'\033[36m' ;;
    warn)  tag="WARN " ; color=$'\033[33m' ;;
    error) tag="ERROR"; color=$'\033[31m' ;;
  esac
  if [ -t 2 ]; then
    printf '%s%s%s %s\n' "$color" "$tag" "$reset" "$*" >&2
  else
    printf '%s %s\n' "$tag" "$*" >&2
  fi
}

log_dbg()  { _devenv_log debug "$@"; }
log_info() { _devenv_log info  "$@"; }
log_warn() { _devenv_log warn  "$@"; }
log_err()  { _devenv_log error "$@"; }

# Source guard for libs that want to avoid re-sourcing log.sh.
_DEVENV_LOG_LOADED=1
