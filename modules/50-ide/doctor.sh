#!/usr/bin/env bash
set -euo pipefail
ok=1
parts=()

if command -v code >/dev/null 2>&1; then
  parts+=("code $(code --version 2>/dev/null | head -n1)")
else
  parts+=("code MISSING")
fi
if command -v cursor >/dev/null 2>&1; then
  parts+=("cursor $(cursor --version 2>/dev/null | head -n1)")
else
  parts+=("cursor MISSING")
fi

case "$(uname -s)" in
  Darwin) base="$HOME/Library/Application Support" ;;
  *)      base="$HOME/.config" ;;
esac
[ -f "$base/Code/User/settings.json" ]   && parts+=("vscode-settings ok")   || parts+=("vscode-settings MISSING")
[ -f "$base/Cursor/User/settings.json" ] && parts+=("cursor-settings ok")   || parts+=("cursor-settings MISSING")

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
