#!/usr/bin/env bash
# TUI prompts. Source me; do not exec.

prompt_confirm() {
  # prompt_confirm "Question?" — returns 0 for yes, 1 for no.
  # Auto-answers "no" when DEVENV_NON_INTERACTIVE=1 (CI / unattended runs).
  if [ "${DEVENV_NON_INTERACTIVE:-0}" = "1" ]; then
    return 1
  fi
  local q="$1"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$q"
    return $?
  fi
  local ans
  printf '%s [y/N] ' "$q" >&2
  read -r ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_input() {
  # prompt_input "Label" "default" — echoes the user's response.
  # Auto-returns the default when DEVENV_NON_INTERACTIVE=1.
  local label="$1" default="${2:-}"
  if [ "${DEVENV_NON_INTERACTIVE:-0}" = "1" ]; then
    echo "$default"
    return 0
  fi
  if command -v gum >/dev/null 2>&1; then
    gum input --prompt "$label > " --value "$default"
    return $?
  fi
  local ans
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$label" "$default" >&2
  else
    printf '%s: ' "$label" >&2
  fi
  read -r ans
  echo "${ans:-$default}"
}
