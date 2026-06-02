#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

parts=()
if [ "${DEVENV_GUI_ENABLED:-0}" = "1" ]; then
  parts+=("opt-in: enabled")
else
  parts+=("opt-in: disabled (set DEVENV_GUI_ENABLED=1)")
fi

brewfile="$ROOT/config/gui/Brewfile"
if [ -f "$brewfile" ] && grep -E -v '^[[:space:]]*(#|$)' "$brewfile" >/dev/null 2>&1; then
  n=$(grep -E -c -v '^[[:space:]]*(#|$)' "$brewfile" || echo 0)
  parts+=("Brewfile: $n entries")
else
  parts+=("Brewfile: empty/template")
fi

printf '%-4s %s\n' "PASS" "$(IFS=, ; echo "${parts[*]}")"
