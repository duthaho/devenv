#!/usr/bin/env bash
set -euo pipefail
DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

ok=1
parts=()

if [ -d "$DIR/.git" ]; then
  branch=$(git -C "$DIR" branch --show-current 2>/dev/null || echo "?")
  parts+=("repo $DIR on $branch")
  if git -C "$DIR" diff --quiet && git -C "$DIR" diff --cached --quiet; then
    parts+=("clean")
  else
    parts+=("dirty")
  fi
else
  ok=0; parts+=("$DIR MISSING")
fi

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
