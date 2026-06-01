#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  source "$ROOT/lib/claude.sh"
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  for tool in claude git; do
    cat > "$STUBS/$tool" <<EOF
#!/usr/bin/env bash
echo "[stub:$tool] \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
    chmod +x "$STUBS/$tool"
  done
  export PATH="$STUBS:$PATH"
}

@test "devenv_claude_plugin_packs_from_file: ignores comments and blanks" {
  cat > "$TEST_TMP/p.txt" <<EOF
# header
anthropics/claude-plugins-official

duthaho/gstack#main
EOF
  run devenv_claude_plugin_packs_from_file "$TEST_TMP/p.txt"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "anthropics/claude-plugins-official" ]
  [ "${lines[1]}" = "duthaho/gstack#main" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "devenv_claude_install_mcp_servers: calls 'claude mcp add-json' per entry" {
  cat > "$TEST_TMP/mcp.json" <<EOF
[
  { "name": "filesystem", "json": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"] } },
  { "name": "github",     "json": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"] } }
]
EOF
  run devenv_claude_install_mcp_servers "$TEST_TMP/mcp.json"
  [ "$status" -eq 0 ]
  grep -q 'mcp add-json filesystem' "$TEST_TMP/calls.log"
  grep -q 'mcp add-json github'     "$TEST_TMP/calls.log"
}

@test "devenv_claude_install_mcp_servers: no-op on empty array" {
  echo '[]' > "$TEST_TMP/mcp.json"
  run devenv_claude_install_mcp_servers "$TEST_TMP/mcp.json"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_TMP/calls.log" ] || ! grep -q 'mcp add-json' "$TEST_TMP/calls.log"
}

@test "devenv_claude_clone_plugin_packs: clones missing repos and skips existing" {
  export DEVENV_CLAUDE_CACHE_DIR="$TEST_TMP/cache"
  mkdir -p "$DEVENV_CLAUDE_CACHE_DIR/anthropics/claude-plugins-official/.git"
  cat > "$TEST_TMP/packs.txt" <<EOF
anthropics/claude-plugins-official
duthaho/gstack
EOF
  run devenv_claude_clone_plugin_packs "$TEST_TMP/packs.txt"
  [ "$status" -eq 0 ]
  grep -q "clone .*duthaho/gstack" "$TEST_TMP/calls.log"
  grep -q "fetch" "$TEST_TMP/calls.log"
}
