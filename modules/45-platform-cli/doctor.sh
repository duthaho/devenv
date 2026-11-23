#!/usr/bin/env bash
set -euo pipefail

doctor_tool() {
  local command_name="$1" display="$2" selected="$3" variable="$4" version
  shift 4
  if command -v "$command_name" >/dev/null 2>&1 && version="$("$command_name" "$@" 2>/dev/null | head -n1)" && [ -n "$version" ]; then
    printf 'PASS %s %s\n' "$display" "$version"
  elif [ "$selected" != "1" ]; then
    printf 'PASS %s not installed (opt-in disabled; set %s=1)\n' "$display" "$variable"
  else
    printf 'WARN %s not installed (opt-in enabled)\n' "$display"
  fi
}

doctor_tool kubectl kubectl "${DEVENV_PLATFORM_KUBECTL:-0}" DEVENV_PLATFORM_KUBECTL version --client
doctor_tool helm Helm "${DEVENV_PLATFORM_HELM:-0}" DEVENV_PLATFORM_HELM version --short
doctor_tool tofu OpenTofu "${DEVENV_PLATFORM_OPENTOFU:-0}" DEVENV_PLATFORM_OPENTOFU version
