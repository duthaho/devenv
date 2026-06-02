#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/repos.sh"

if [ "${DEVENV_SKIP_REPO_CLONE:-0}" = "1" ]; then
  log_info "70-repos: skipped (DEVENV_SKIP_REPO_CLONE=1)"
  exit 0
fi

file="${DEVENV_REPOS_FILE:-$ROOT/config/repos.txt}"
if [ ! -f "$file" ]; then
  log_info "70-repos: no $file; nothing to do"
  log_info "70-repos: done"
  exit 0
fi

count=0
while IFS=$'\t' read -r remote path setup; do
  [ -n "$remote" ] || continue
  log_info "sync $remote -> $path"
  devenv_repos_sync_one "$remote" "$path" "$setup"
  count=$((count + 1))
done < <(devenv_repos_parse_file "$file")

log_info "70-repos: synced $count repo(s)"
log_info "70-repos: done"
