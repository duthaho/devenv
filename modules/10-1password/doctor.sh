#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/op.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

OS="$(devenv_os)"
ok=1
parts=()

if command -v op >/dev/null 2>&1; then
  parts+=("op $(op --version 2>/dev/null || echo unknown)")
else
  ok=0; parts+=("op MISSING")
fi

if op_signed_in; then
  parts+=("signed-in")
else
  # Not-signed-in is a soft fail on Linux/WSL where sessions are per-shell.
  case "$OS" in
    linux|wsl) parts+=("not-signed-in (run: eval \"\$(op signin)\")") ;;
    *)         ok=0; parts+=("not-signed-in") ;;
  esac
fi

# SSH config is only expected when the desktop app is present (mac/windows).
case "$OS" in
  mac|windows)
    if [ -f "$HOME/.ssh/config.d/10-1password.conf" ]; then
      parts+=("ssh-config ok")
    else
      ok=0; parts+=("ssh-config MISSING")
    fi
    ;;
  linux|wsl)
    parts+=("ssh-config n/a (no desktop agent)")
    ;;
esac

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
