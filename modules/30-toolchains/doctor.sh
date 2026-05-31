#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

OS="$(devenv_os)"
ok=1
parts=()

command -v mise   >/dev/null 2>&1 && parts+=("mise $(mise --version 2>/dev/null | awk '{print $1}')") || { ok=0; parts+=("mise MISSING"); }
command -v direnv >/dev/null 2>&1 && parts+=("direnv $(direnv --version)")                              || { ok=0; parts+=("direnv MISSING"); }

case "$OS" in
  windows)
    parts+=("devbox n/a (native Windows)")
    ;;
  *)
    command -v devbox >/dev/null 2>&1 && parts+=("devbox $(devbox version 2>/dev/null | head -n1)") || { ok=0; parts+=("devbox MISSING"); }
    ;;
esac

[ -f "$HOME/.config/mise/config.toml" ] && parts+=("mise-config ok") || { ok=0; parts+=("mise-config MISSING"); }

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
