#!/usr/bin/env bash
set -euo pipefail
ok=1
parts=()

if command -v docker >/dev/null 2>&1; then
  parts+=("docker $(docker --version | awk '{print $3}' | tr -d ',')")
else
  ok=0; parts+=("docker MISSING")
fi

if docker info >/dev/null 2>&1; then
  parts+=("engine ok")
else
  ok=0; parts+=("engine UNREACHABLE")
fi

if docker compose version >/dev/null 2>&1; then
  parts+=("compose v2 ok")
else
  ok=0; parts+=("compose v2 MISSING")
fi

if docker network inspect devenv >/dev/null 2>&1; then
  parts+=("network devenv ok")
else
  ok=0; parts+=("network devenv MISSING")
fi

status=$([ "$ok" -eq 1 ] && echo PASS || echo FAIL)
printf '%-4s %s\n' "$status" "$(IFS=, ; echo "${parts[*]}")"
[ "$ok" -eq 1 ]
