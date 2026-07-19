#!/usr/bin/env bash
# Curated first-run menu: pick optional modules + language toolchains.
# Source me; do not exec. Assumes lib/log.sh and lib/markers.sh are sourced.

# Optional modules the menu offers, and the subset pre-ticked by default
# (80-gui is opt-in today, so it starts unchecked).
_DEVENV_MENU_MODULES="50-ide 60-claude 70-repos 80-gui"
_DEVENV_MENU_MODULES_DEFAULT="50-ide 60-claude 70-repos"

# devenv_menu_langs_available <mise.config.toml> — print the [tools] keys, one
# per line, in file order.
devenv_menu_langs_available() {
  local cfg="$1"
  [ -r "$cfg" ] || return 1
  awk '
    /^\[tools\]/ { intools = 1; next }
    /^\[/        { intools = 0; next }
    intools && /=/ {
      key = $0
      sub(/[[:space:]]*=.*$/, "", key)
      gsub(/[[:space:]]/, "", key)
      if (key != "") print key
    }
  ' "$cfg"
}

# _devenv_first_run — true (0) when no *.done markers exist in the cache dir.
_devenv_first_run() {
  local dir
  dir="$(_devenv_cache_dir)"
  ! ls "$dir"/*.done >/dev/null 2>&1
}

# devenv_menu_should_show <reconfigure> — decide whether to present the menu.
# 0 = show, 1 = don't. Order of guards matters (see spec D6).
devenv_menu_should_show() {
  local reconfigure="${1:-0}"
  [ "${DEVENV_NON_INTERACTIVE:-0}" = "1" ] && return 1
  command -v gum >/dev/null 2>&1 || return 1
  [ "$reconfigure" = "1" ] && return 0
  _devenv_first_run || return 1
  [ -t 0 ] || return 1
  return 0
}
