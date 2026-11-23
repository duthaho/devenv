#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
. "$ROOT/lib/versions.sh"

install_codex_cli() {
  if [ "${DEVENV_AI_CLI_ENABLED:-0}" != "1" ]; then
    log_info "65-ai-cli skipped (set DEVENV_AI_CLI_ENABLED=1 or select it in the menu)"
    return 0
  fi
  if [ "${DEVENV_SKIP_NPM_INSTALL:-0}" = "1" ] || [ "${DEVENV_SKIP_CODEX_INSTALL:-0}" = "1" ]; then
    log_info "codex install skipped (DEVENV_SKIP_NPM_INSTALL or DEVENV_SKIP_CODEX_INSTALL)"
    return 0
  fi

  if command -v codex >/dev/null 2>&1; then
    local installed drift
    installed="$(codex --version 2>/dev/null | head -n1)"
    drift="$(devenv_tool_drift codex "$installed")"
    [ -z "$drift" ] || log_warn "codex $installed; manifest $drift; run: npm install -g $(devenv_npm_spec codex)"
    log_info "codex $installed already installed"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    log_warn "Node/npm not on PATH; install Node via 30-toolchains (mise install node@lts), then re-run --only 65-ai-cli."
    return 0
  fi

  local spec
  spec="$(devenv_npm_spec codex)"
  log_info "npm install -g $spec"
  npm install -g "$spec" >/dev/null
  if ! command -v codex >/dev/null 2>&1 || ! codex --version >/dev/null 2>&1; then
    log_err "Codex installation completed but 'codex --version' is unavailable. Restart the shell to refresh mise shims, then re-run --only 65-ai-cli."
    return 1
  fi
  drift="$(devenv_tool_drift codex "$(codex --version 2>/dev/null | head -n1)")"
  [ -z "$drift" ] || { log_err "codex version mismatch: $drift"; return 1; }
  log_info "codex $(codex --version | head -n1) installed"
}

install_codex_cli
log_info "65-ai-cli: done"
