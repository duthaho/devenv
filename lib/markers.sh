#!/usr/bin/env bash
# Idempotency markers under $DEVENV_CACHE_DIR (default: ~/.cache/devenv).
# Source me; do not exec.

_devenv_cache_dir() {
  echo "${DEVENV_CACHE_DIR:-$HOME/.cache/devenv}"
}

_devenv_sha256() {
  # Read from stdin, output hex digest (no filename).
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    return 1
  fi
}

marker_path() {
  local module="$1"
  printf '%s/%s.done\n' "$(_devenv_cache_dir)" "$module"
}

module_sha() {
  local mod="$1"
  [ -d "$mod" ] || { echo "" ; return 1; }
  # Iterate candidates in a fixed deterministic order — DO NOT sort.
  # bash `sort` is case-sensitive (ASCII: R<d) while PowerShell `Sort-Object`
  # is case-insensitive on Windows. Sorting would produce divergent SHAs
  # across platforms. The candidates list IS the canonical order.
  local files=()
  local f
  for f in run.sh run.ps1 doctor.sh doctor.ps1 README.md; do
    [ -f "$mod/$f" ] && files+=("$mod/$f")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    echo ""
    return 1
  fi
  cat -- "${files[@]}" 2>/dev/null | _devenv_sha256
}

is_done() {
  local module="$1" want_sha="$2"
  local p
  p="$(marker_path "$module")"
  [ -r "$p" ] || return 1
  local got
  got="$(cat "$p" 2>/dev/null)"
  [ "$got" = "$want_sha" ]
}

mark_done() {
  local module="$1" sha="$2"
  local p
  p="$(marker_path "$module")"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "$sha" > "$p"
}

clear_done() {
  local module="$1"
  local p
  p="$(marker_path "$module")"
  rm -f "$p"
}
