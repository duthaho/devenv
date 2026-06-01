#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  for tool in claude npm git curl; do
    cat > "$STUBS/$tool" <<EOF
#!/usr/bin/env bash
echo "[stub:$tool] \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
    chmod +x "$STUBS/$tool"
  done
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME"
  export DEVENV_CLAUDE_CACHE_DIR="$TEST_TMP/cache"
  export DEVENV_SKIP_NPM_INSTALL=1
}

@test "60-claude: completes when claude already present" {
  run bash "$ROOT/modules/60-claude/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"60-claude: done"* ]]
}

@test "60-claude: clones plugin packs listed in config" {
  echo "anthropics/claude-plugins-official" > "$ROOT/config/claude/plugin-packs.txt.test"
  DEVENV_CLAUDE_PLUGIN_FILE="$ROOT/config/claude/plugin-packs.txt.test" \
    bash "$ROOT/modules/60-claude/run.sh" >/dev/null
  rm -f "$ROOT/config/claude/plugin-packs.txt.test"
  grep -q "clone .*anthropics/claude-plugins-official" "$TEST_TMP/calls.log"
}
