#!/usr/bin/env bash
# 1Password CLI wrappers. Source me; do not exec.
# Honors OP_MOCK=1 to short-circuit secret reads (for CI + tests).

# Resolve sibling log lib if available.
if [ -z "${_DEVENV_LOG_LOADED:-}" ] && [ -f "${BASH_SOURCE[0]%/*}/log.sh" ]; then
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/log.sh"
  _DEVENV_LOG_LOADED=1
fi

op_available() {
  command -v op >/dev/null 2>&1
}

op_signed_in() {
  if [ "${OP_MOCK:-0}" = "1" ]; then
    return 0
  fi
  op_available || return 1
  op whoami >/dev/null 2>&1
}

op_require_signin() {
  if op_signed_in; then
    return 0
  fi
  log_err "1Password CLI is not signed in. Run:  op signin"
  log_err "Make sure the desktop app is open and 'Integrate with 1Password CLI' is enabled."
  return 1
}

op_read() {
  local path
  path="$1"
  if [ "${OP_MOCK:-0}" = "1" ]; then
    printf 'mock-value\n'
    return 0
  fi
  op_require_signin || return 1
  op read "$path"
}

op_inject() {
  local input output
  input="$1"
  output="$2"
  if [ "${OP_MOCK:-0}" = "1" ]; then
    cp "$input" "$output"
    return 0
  fi
  op_require_signin || return 1
  op inject -i "$input" -o "$output"
}
