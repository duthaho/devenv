#!/usr/bin/env bash
# GUI module helpers. Source me; do not exec.

# Returns 0 (true) when GUI installs are opted in.
devenv_gui_enabled() {
  [ "${DEVENV_GUI_ENABLED:-0}" = "1" ]
}

# Returns 0 if the file has any non-comment, non-blank line; 1 otherwise.
devenv_gui_has_entries() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -E -v '^[[:space:]]*(#|$)' "$file" >/dev/null 2>&1
}

# Run `brew bundle --file=<Brewfile>` if brew is on PATH and the Brewfile has entries.
devenv_gui_brew_bundle() {
  local file="$1"
  [ -f "$file" ] || return 0
  devenv_gui_has_entries "$file" || return 0
  command -v brew >/dev/null 2>&1 || { echo "  brew not on PATH; skipping bundle" >&2; return 0; }
  brew bundle --file="$file" >/dev/null 2>&1 || echo "  brew bundle failed (check $file)" >&2
}
