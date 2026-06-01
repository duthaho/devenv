#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/os.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/claude.sh"

install_claude_cli() {
  [ "${DEVENV_SKIP_NPM_INSTALL:-0}" = "1" ] && { log_info "claude install skipped (DEVENV_SKIP_NPM_INSTALL=1)"; return 0; }
  if command -v claude >/dev/null 2>&1; then log_info "claude $(claude --version 2>/dev/null | head -n1) already installed"; return 0; fi
  if ! command -v npm >/dev/null 2>&1; then
    log_warn "npm not on PATH; install Node via 30-toolchains (mise install node@lts) then re-run --only 60-claude."
    return 0
  fi
  log_info "npm install -g @anthropic-ai/claude-code"
  npm install -g @anthropic-ai/claude-code >/dev/null
}

apply_mcp_servers() {
  local file="$ROOT/config/claude/mcp-servers.json"
  [ -f "$file" ] || return 0
  devenv_claude_install_mcp_servers "$file"
}

apply_plugin_packs() {
  local file="${DEVENV_CLAUDE_PLUGIN_FILE:-$ROOT/config/claude/plugin-packs.txt}"
  [ -f "$file" ] || return 0
  devenv_claude_clone_plugin_packs "$file"
}

install_claude_cli
apply_mcp_servers
apply_plugin_packs
log_info "60-claude: done"
