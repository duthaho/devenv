#!/usr/bin/env bash
# Environment / host-wiring health checks for `devenv doctor`. Source me; do not exec.
#
# Each check function echoes ONE line "<STATUS> <name> <detail>" (or nothing to
# skip) and returns 0=PASS, 2=WARN, 1=FAIL. The aggregator decides overall
# failure by RETURN CODE, never by parsing the (indented) printed line.

_devenv_doctor_dir="${BASH_SOURCE[0]%/*}"
# shellcheck disable=SC1091
[ -f "$_devenv_doctor_dir/os.sh" ] && . "$_devenv_doctor_dir/os.sh"
# shellcheck disable=SC1091
[ -f "$_devenv_doctor_dir/op.sh" ] && . "$_devenv_doctor_dir/op.sh"
# shellcheck disable=SC1091
if [ -z "${_DEVENV_LOG_LOADED:-}" ] && [ -f "$_devenv_doctor_dir/log.sh" ]; then
  . "$_devenv_doctor_dir/log.sh"
fi

# devenv_dcheck_os — informational OS/distro banner. Always PASS.
devenv_dcheck_os() {
  local os distro detail
  os="$(devenv_os)"
  distro="$(devenv_distro)"
  detail="$os"
  [ -n "$distro" ] && detail="$os/$distro"
  echo "PASS os $detail"
  return 0
}

# devenv_dcheck_op — 1Password CLI reachability + signed-in state.
# Reuses op_available/op_signed_in (honor OP_MOCK=1). Not-signed-in is a soft
# WARN on linux/wsl (per-shell sessions) but a hard FAIL on mac/windows.
devenv_dcheck_op() {
  local os; os="$(devenv_os)"
  if [ "${OP_MOCK:-0}" != "1" ] && ! op_available; then
    echo "FAIL op op CLI MISSING"
    return 1
  fi
  if op_signed_in; then
    echo "PASS op signed-in"
    return 0
  fi
  case "$os" in
    linux|wsl) echo 'WARN op not-signed-in (run: eval "$(op signin)")'; return 2 ;;
    *)         echo "FAIL op not-signed-in"; return 1 ;;
  esac
}

# devenv_dcheck_ssh_agent — SSH agent socket wired (1Password agent, usually).
devenv_dcheck_ssh_agent() {
  local os; os="$(devenv_os)"
  if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
    echo "PASS ssh-agent agent socket present"
    return 0
  fi
  case "$os" in
    mac|windows) echo "WARN ssh-agent no agent socket (expected 1Password agent)"; return 2 ;;
    *)           echo "WARN ssh-agent no agent socket"; return 2 ;;
  esac
}

# devenv_dcheck_shell_hooks — mise + direnv activation wired into a shell rc.
# Missing hooks are advisory (WARN): shims on PATH can substitute for them.
devenv_dcheck_shell_hooks() {
  local f mise_ok=0 direnv_ok=0 miss=""
  local files=(
    "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"
    "$HOME/.config/fish/config.fish"
  )
  for f in "${files[@]}"; do
    [ -r "$f" ] || continue
    grep -q 'mise activate' "$f" 2>/dev/null && mise_ok=1
    grep -q 'direnv hook'   "$f" 2>/dev/null && direnv_ok=1
  done
  if [ "$mise_ok" -eq 1 ] && [ "$direnv_ok" -eq 1 ]; then
    echo "PASS shell-hooks mise+direnv wired"
    return 0
  fi
  [ "$mise_ok" -eq 0 ] && miss="mise"
  [ "$direnv_ok" -eq 0 ] && miss="${miss:+$miss+}direnv"
  echo "WARN shell-hooks missing hook: $miss"
  return 2
}

# devenv_dcheck_shims — mise shims directory resolvable on PATH. If shims are
# absent but mise itself resolves (via an activate hook), that's a WARN; if mise
# is unreachable entirely, tools won't resolve in a fresh shell — FAIL.
devenv_dcheck_shims() {
  case "$PATH" in
    *mise/shims*|*mise\\shims*)
      echo "PASS shims mise shims on PATH"
      return 0
      ;;
  esac
  if command -v mise >/dev/null 2>&1; then
    echo "WARN shims mise present but shims dir not on PATH (relying on activate hook)"
    return 2
  fi
  echo "FAIL shims mise not resolvable (shims missing, no hook)"
  return 1
}

# devenv_doctor_env — run every check in order, print each line indented, and
# return 1 if any check returned 1 (FAIL), else 0. WARN never fails the result.
devenv_doctor_env() {
  local checks=(devenv_dcheck_os)
  local chk line rc worst=0 status name rest
  for chk in "${checks[@]}"; do
    line="$("$chk")"; rc=$?
    if [ -n "$line" ]; then
      read -r status name rest <<<"$line"
      printf '  %-5s %-11s %s\n' "$status" "$name" "$rest"
    fi
    [ "$rc" -eq 1 ] && worst=1
  done
  return "$worst"
}
