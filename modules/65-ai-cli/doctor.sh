#!/usr/bin/env bash
set -euo pipefail

if command -v codex >/dev/null 2>&1 && version="$(codex --version 2>/dev/null | head -n1)" && [ -n "$version" ]; then
  printf 'PASS codex %s\n' "$version"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  printf 'FAIL codex MISSING (Node MISSING; install via 30-toolchains)\n'
elif ! command -v npm >/dev/null 2>&1; then
  printf 'FAIL codex MISSING (npm MISSING; install Node via 30-toolchains)\n'
else
  printf 'FAIL codex MISSING\n'
fi
exit 1
