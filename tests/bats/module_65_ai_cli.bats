#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export PATH="$STUBS:$PATH"
  export BASH_BIN="$(command -v bash)"
  export CHMOD_BIN="$(command -v chmod)"
  export DIRNAME_BIN="$(command -v dirname)"
  export HEAD_BIN="$(command -v head)"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME"
  export DEVENV_AI_CLI_ENABLED=1
  guard_network
}

@test "65-ai-cli: module passes pinned manifest spec to npm" {
  cp "$ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  portable_sed_in_place 's/codex.version=latest/codex.version=0.1.2/' "$TEST_TMP/versions.txt"
  stub_tool node 'exit 0'
  stub_tool npm 'echo "npm $*" >> "$TEST_TMP/calls.log"; printf "#!/usr/bin/env bash\necho codex 0.1.2\n" > "$STUBS/codex"; chmod +x "$STUBS/codex"'
  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" PATH="$STUBS:/usr/bin:/bin" "$BASH_BIN" "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q '@openai/codex@0.1.2' "$TEST_TMP/calls.log"
  [ -z "$(git -C "$ROOT" status --porcelain modules/)" ]
}

stub_tool() {
  local name="$1" body="$2"
  printf '#!%s\n%s\n' "$BASH_BIN" "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

@test "65-ai-cli: installs Codex through npm and verifies its version" {
  stub_tool node 'exit 0'
  stub_tool npm 'echo "npm $*" >> "$TEST_TMP/calls.log"; printf "#!%s\\necho codex 1.2.3\\n" "$BASH_BIN" > "$STUBS/codex"; "$CHMOD_BIN" +x "$STUBS/codex"'

  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  stub_tool head '"$HEAD_BIN" "$@"'
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"65-ai-cli: done"* ]]
  grep -q 'npm install -g @openai/codex' "$TEST_TMP/calls.log"
}

@test "65-ai-cli: does not invoke npm when Codex is already installed" {
  stub_tool codex 'echo codex 1.2.3'
  stub_tool npm 'echo unexpected >> "$TEST_TMP/calls.log"; exit 1'

  run bash "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_TMP/calls.log" ]
}

@test "65-ai-cli: warns on a pinned installed version drift without invoking npm" {
  cp "$ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  portable_sed_in_place 's/codex.version=latest/codex.version=0.1.2/' "$TEST_TMP/versions.txt"
  stub_tool codex 'echo codex 0.0.9'
  stub_tool npm 'echo unexpected >> "$TEST_TMP/calls.log"; exit 1'

  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" PATH="$STUBS:/usr/bin:/bin" "$BASH_BIN" "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'pinned 0.1.2, installed 0.0.9'* ]]
  [ ! -e "$TEST_TMP/calls.log" ]
}

@test "65-ai-cli doctor: reports pinned Codex version drift" {
  cp "$ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  portable_sed_in_place 's/codex.version=latest/codex.version=0.1.2/' "$TEST_TMP/versions.txt"
  stub_tool codex 'echo codex 0.0.9'
  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" PATH="$STUBS:/usr/bin:/bin" "$BASH_BIN" "$ROOT/modules/65-ai-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'WARN codex codex 0.0.9 (pinned 0.1.2, installed 0.0.9)'* ]]
}

@test "65-ai-cli: does not install until explicitly selected" {
  unset DEVENV_AI_CLI_ENABLED
  stub_tool npm 'echo unexpected >> "$TEST_TMP/calls.log"; exit 1'

  run bash "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"65-ai-cli skipped"* ]]
  [ ! -e "$TEST_TMP/calls.log" ]
}

@test "65-ai-cli doctor: reports missing Node when Codex is absent" {
  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/65-ai-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Node MISSING"* ]]
}

@test "65-ai-cli doctor: passes when the opt-in module is disabled" {
  unset DEVENV_AI_CLI_ENABLED
  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/65-ai-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"opt-in disabled"* ]]
}
