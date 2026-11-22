#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"

OS="$(devenv_os)"
ok=1
status="PASS"
parts=()

case "$OS" in
  mac)
    command -v brew >/dev/null 2>&1 && parts+=("brew $(brew --version | head -n1 | awk '{print $2}')") || { ok=0; parts+=("brew MISSING"); }
    ;;
  linux|wsl)
    command -v curl >/dev/null 2>&1 && parts+=("curl ok") || { ok=0; parts+=("curl MISSING"); }
    ;;
  windows)
    command -v winget >/dev/null 2>&1 && parts+=("winget ok") || { ok=0; parts+=("winget MISSING"); }
    ;;
esac
command -v git  >/dev/null 2>&1 && parts+=("git $(git --version | awk '{print $3}')")  || { ok=0; parts+=("git MISSING"); }
command -v jq   >/dev/null 2>&1 && parts+=("jq $(jq --version)")                       || { ok=0; parts+=("jq MISSING"); }
command -v gum  >/dev/null 2>&1 && parts+=("gum $(gum --version | awk '{print $3}')") || { ok=0; parts+=("gum MISSING"); }
command -v gh   >/dev/null 2>&1 && parts+=("gh $(gh --version | head -n1 | awk '{print $3}')") || { ok=0; parts+=("gh MISSING"); }
optional_command() {
  command -v "$1" >/dev/null 2>&1 && parts+=("$1 ok") || parts+=("$1 OPTIONAL-MISSING")
}
optional_command fzf
optional_command rg
optional_command bat
optional_command zoxide

[ "$ok" -eq 1 ] || status="FAIL"
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
