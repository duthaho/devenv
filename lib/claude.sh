#!/usr/bin/env bash
# Claude Code helpers. Source me; do not exec.

devenv_claude_plugin_packs_from_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  sed -E 's/[[:space:]]+$//' "$file" | grep -E -v '^[[:space:]]*(#|$)' || true
}

devenv_claude_install_mcp_servers() {
  local file="$1"
  [ -f "$file" ] || return 0
  command -v claude >/dev/null 2>&1 || { echo "  claude not on PATH; skipping mcp add-json" >&2; return 0; }
  command -v jq     >/dev/null 2>&1 || { echo "  jq required for mcp servers" >&2; return 1; }
  local count
  count="$(jq 'length' "$file")"
  [ "$count" -gt 0 ] 2>/dev/null || return 0
  local i
  for i in $(seq 0 $((count - 1))); do
    local name json
    name="$(jq -r ".[$i].name" "$file")"
    json="$(jq -c ".[$i].json"  "$file")"
    claude mcp add-json "$name" "$json" >/dev/null 2>&1 || echo "  mcp add-json failed for $name" >&2
  done
}

devenv_claude_clone_plugin_packs() {
  local file="$1"
  [ -f "$file" ] || return 0
  command -v git >/dev/null 2>&1 || { echo "  git required for plugin packs" >&2; return 1; }
  local cache="${DEVENV_CLAUDE_CACHE_DIR:-$HOME/.claude/plugins/cache}"
  local entry
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    local repo ref
    repo="${entry%%#*}"
    ref=""
    [ "$repo" != "$entry" ] && ref="${entry##*#}"
    local target="$cache/$repo"
    if [ -d "$target/.git" ]; then
      git -C "$target" fetch --depth 1 origin "${ref:-HEAD}" >/dev/null 2>&1 || echo "  fetch failed: $repo" >&2
    else
      mkdir -p "$(dirname "$target")"
      git clone --depth 1 "https://github.com/$repo.git" "$target" >/dev/null 2>&1 || echo "  clone failed: $repo" >&2
      if [ -n "$ref" ] && [ -d "$target/.git" ]; then
        git -C "$target" checkout "$ref" >/dev/null 2>&1 || true
      fi
    fi
  done < <(devenv_claude_plugin_packs_from_file "$file")
}
