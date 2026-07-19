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
