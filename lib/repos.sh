#!/usr/bin/env bash
# Repo-sync helpers. Source me; do not exec.

# Print the default clone path for a remote URL: ~/code/<basename, .git stripped>.
devenv_repos_default_path() {
  local remote="$1" base
  base="${remote##*/}"
  base="${base%.git}"
  printf '%s\n' "$HOME/code/$base"
}

# Parse repos.txt into tab-separated `remote<TAB>path<TAB>setup` rows.
# Comments (#) and blank lines are skipped. Missing path -> default. Missing setup -> empty.
devenv_repos_parse_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk -F'|' -v home="$HOME" '
    {
      sub(/[[:space:]]+$/, "", $0)
      if ($0 ~ /^[[:space:]]*(#|$)/) next
      remote = $1; gsub(/^[[:space:]]+|[[:space:]]+$/, "", remote)
      path   = ""; if (NF >= 2) { path = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", path) }
      setup  = ""; if (NF >= 3) { setup = $3; for (i=4; i<=NF; i++) setup = setup "|" $i; gsub(/^[[:space:]]+|[[:space:]]+$/, "", setup) }
      if (path == "") {
        n = split(remote, parts, "/")
        base = parts[n]; sub(/\.git$/, "", base)
        path = home "/code/" base
      } else if (substr(path, 1, 2) == "~/") {
        path = home substr(path, 2)
      }
      printf "%s\t%s\t%s\n", remote, path, setup
    }
  ' "$file"
}

# Clone (depth=1) if target missing, otherwise git fetch. Then run setup in repo root if given.
devenv_repos_sync_one() {
  local remote="$1" path="$2" setup="${3:-}"
  command -v git >/dev/null 2>&1 || { echo "  git required for repo sync" >&2; return 1; }
  if [ -d "$path/.git" ]; then
    git -C "$path" fetch --tags --prune >/dev/null 2>&1 || echo "  fetch failed: $remote" >&2
  else
    mkdir -p "$(dirname "$path")"
    git clone --depth 1 "$remote" "$path" >/dev/null 2>&1 || { echo "  clone failed: $remote" >&2; return 0; }
  fi
  if [ -n "$setup" ] && [ -d "$path" ]; then
    ( cd "$path" && sh -c "$setup" ) || echo "  setup failed in $path" >&2
  fi
}
