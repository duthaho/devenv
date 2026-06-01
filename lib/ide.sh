#!/usr/bin/env bash
# IDE helpers. Source me; do not exec.

devenv_ide_extensions_from_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  sed -E 's/[[:space:]]+$//' "$file" | grep -E -v '^[[:space:]]*(#|$)' || true
}

devenv_ide_merge_settings() {
  local overlay="$1" user="$2"
  command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; return 1; }
  mkdir -p "$(dirname "$user")"
  if [ ! -f "$user" ] || [ ! -s "$user" ]; then
    jq '.' "$overlay" > "$user"
    return 0
  fi
  local tmp="${user}.devenv.tmp"
  jq -s '.[0] * .[1]' "$user" "$overlay" > "$tmp" && mv -- "$tmp" "$user"
}

devenv_ide_install_extensions() {
  local cli="$1" file="$2"
  command -v "$cli" >/dev/null 2>&1 || return 0
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    "$cli" --install-extension "$id" --force >/dev/null 2>&1 || echo "  $cli install failed: $id" >&2
  done < <(devenv_ide_extensions_from_file "$file")
}
