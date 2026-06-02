#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/repos.sh"

ok=1
parts=()

if command -v git >/dev/null 2>&1; then
  parts+=("git ok")
else
  ok=0; parts+=("git MISSING")
fi

file="$ROOT/config/repos.txt"
configured=0
present=0
if [ -f "$file" ]; then
  while IFS=$'\t' read -r _remote path _setup; do
    [ -n "$path" ] || continue
    configured=$((configured + 1))
    [ -d "$path/.git" ] && present=$((present + 1))
  done < <(devenv_repos_parse_file "$file")
fi
parts+=("repos $present/$configured present")

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
