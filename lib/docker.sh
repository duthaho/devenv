#!/usr/bin/env bash
# Compose path + invocation contract. Source me; do not exec.

devenv_compose_main_path() {
  local here root
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$here/.." && pwd)"
  echo "$root/services/compose.yml"
}

devenv_compose_local_path() {
  echo "$HOME/.devenv/services/compose.local.yml"
}

devenv_compose_args() {
  local args local_path
  args="-f $(devenv_compose_main_path)"
  local_path="$(devenv_compose_local_path)"
  [ -f "$local_path" ] && args="$args -f $local_path"
  echo "$args"
}

devenv_db_for_project() {
  local proj="$1"
  echo "${proj}_dev"
}
