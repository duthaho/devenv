#!/usr/bin/env bash
set -euo pipefail

if command -v codex >/dev/null 2>&1 && version="$(codex --version 2>/dev/null | head -n1)" && [ -n "$version" ]; then
  printf 'PASS codex %s\n' "$version"
  exit 0
fi

if [ "${DEVENV_AI_CLI_ENABLED:-0}" != "1" ]; then
  printf 'PASS codex not installed (opt-in disabled; set DEVENV_AI_CLI_ENABLED=1)\n'
elif ! command -v node >/dev/null 2>&1; then
  printf 'WARN codex not installed (Node MISSING; install via 30-toolchains)\n'
elif ! command -v npm >/dev/null 2>&1; then
  printf 'WARN codex not installed (npm MISSING; install Node via 30-toolchains)\n'
else
  printf 'WARN codex not installed (opt-in enabled)\n'
fi
exit 0
