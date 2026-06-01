#!/usr/bin/env bash
set -euo pipefail
ok=1
parts=()

if command -v claude >/dev/null 2>&1; then
  parts+=("claude $(claude --version 2>/dev/null | head -n1)")
else
  ok=0; parts+=("claude MISSING")
fi

cache="$HOME/.claude/plugins/cache"
n=0
if [ -d "$cache" ]; then
  while IFS= read -r d; do n=$((n+1)); done < <(find "$cache" -mindepth 2 -maxdepth 2 -type d -name '.git' 2>/dev/null)
fi
parts+=("plugin-packs $n")

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
