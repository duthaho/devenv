#!/usr/bin/env bash
set -euo pipefail

doctor_wrangler() {
  if command -v wrangler >/dev/null 2>&1 && version="$(wrangler --version 2>/dev/null | head -n1)" && [ -n "$version" ]; then
    printf 'PASS wrangler %s\n' "$version"
  elif [ "${DEVENV_CLOUD_WRANGLER:-0}" != "1" ]; then
    printf 'PASS wrangler not installed (opt-in disabled; set DEVENV_CLOUD_WRANGLER=1)\n'
  elif ! command -v node >/dev/null 2>&1; then
    printf 'WARN wrangler not installed (Node MISSING; install via 30-toolchains)\n'
  elif ! command -v npm >/dev/null 2>&1; then
    printf 'WARN wrangler not installed (npm MISSING; install Node via 30-toolchains)\n'
  else
    printf 'WARN wrangler not installed (opt-in enabled)\n'
  fi
}

doctor_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1 && version="$(cloudflared --version 2>/dev/null | head -n1)" && [ -n "$version" ]; then
    printf 'PASS cloudflared %s\n' "$version"
  elif [ "${DEVENV_CLOUD_CLOUDFLARED:-0}" != "1" ]; then
    printf 'PASS cloudflared not installed (opt-in disabled; set DEVENV_CLOUD_CLOUDFLARED=1)\n'
  else
    printf 'WARN cloudflared not installed (opt-in enabled)\n'
  fi
}

doctor_aws() {
  local version
  if command -v aws >/dev/null 2>&1 && version="$(aws --version 2>&1 | head -n1)" && [[ "$version" == aws-cli/2.* ]]; then
    printf 'PASS AWS CLI v2 %s\n' "$version"
  elif command -v aws >/dev/null 2>&1 && version="$(aws --version 2>&1 | head -n1)"; then
    printf 'WARN AWS CLI v1 installed (%s); v2 is required\n' "$version"
  elif [ "${DEVENV_CLOUD_AWS:-0}" != "1" ]; then
    printf 'PASS AWS CLI not installed (opt-in disabled; set DEVENV_CLOUD_AWS=1)\n'
  else
    printf 'WARN AWS CLI v2 not installed (opt-in enabled)\n'
  fi
}

doctor_wrangler
doctor_cloudflared
doctor_aws
