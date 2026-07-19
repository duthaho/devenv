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

# _devenv_words_to_csv w1 w2 … — join args with commas.
_devenv_words_to_csv() { local IFS=,; echo "$*"; }

# _devenv_in_words <needle> w1 w2 … — 0 if needle is one of the words.
_devenv_in_words() {
  local needle="$1"; shift
  local w
  for w in "$@"; do [ "$w" = "$needle" ] && return 0; done
  return 1
}

# devenv_menu_run <mise.config.toml> — present the checklists and translate the
# selection into: global DEVENV_MENU_SKIP (csv of optional modules to skip),
# exported DEVENV_LANGS (csv of chosen languages), and DEVENV_GUI_ENABLED=1 when
# 80-gui is chosen. Returns non-zero (leaving those unset) if gum is cancelled,
# so the caller falls back to defaults.
devenv_menu_run() {
  local cfg="$1"
  local mods_default_csv chosen_mods langs_all langs_all_csv chosen_langs

  # shellcheck disable=SC2086
  mods_default_csv="$(_devenv_words_to_csv $_DEVENV_MENU_MODULES_DEFAULT)"
  # shellcheck disable=SC2086
  chosen_mods="$(gum choose --no-limit --header 'Select optional modules' \
    --selected "$mods_default_csv" $_DEVENV_MENU_MODULES)" \
    || { log_warn 'menu: module selection cancelled; keeping defaults'; return 1; }

  langs_all="$(devenv_menu_langs_available "$cfg")"
  # shellcheck disable=SC2086
  langs_all_csv="$(_devenv_words_to_csv $langs_all)"
  # shellcheck disable=SC2086
  chosen_langs="$(gum choose --no-limit --header 'Select languages (mise)' \
    --selected "$langs_all_csv" $langs_all)" \
    || { log_warn 'menu: language selection cancelled; keeping defaults'; return 1; }

  local m skip=""
  for m in $_DEVENV_MENU_MODULES; do
    # shellcheck disable=SC2086
    if ! _devenv_in_words "$m" $chosen_mods; then
      skip="${skip:+$skip,}$m"
    fi
  done
  DEVENV_MENU_SKIP="$skip"

  # shellcheck disable=SC2086
  if _devenv_in_words "80-gui" $chosen_mods; then
    export DEVENV_GUI_ENABLED=1
  fi

  # shellcheck disable=SC2086
  export DEVENV_LANGS="$(_devenv_words_to_csv $chosen_langs)"
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
