#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME"
  export DEVENV_AI_CLI_ENABLED=1
}

stub_tool() {
  local name="$1" body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

@test "65-ai-cli: installs Codex through npm and verifies its version" {
  stub_tool node 'exit 0'
  stub_tool npm 'echo "npm $*" >> "$TEST_TMP/calls.log"; printf "#!/usr/bin/env bash\\necho codex 1.2.3\\n" > "$STUBS/codex"; chmod +x "$STUBS/codex"'

  run env PATH="$STUBS:/usr/bin:/bin" bash "$ROOT/modules/65-ai-cli/run.sh"
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

@test "65-ai-cli: does not install until explicitly selected" {
  unset DEVENV_AI_CLI_ENABLED
  stub_tool npm 'echo unexpected >> "$TEST_TMP/calls.log"; exit 1'

  run bash "$ROOT/modules/65-ai-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"65-ai-cli skipped"* ]]
  [ ! -e "$TEST_TMP/calls.log" ]
}

@test "65-ai-cli doctor: reports missing Node when Codex is absent" {
  stub_tool dirname '/usr/bin/dirname "$@"'
  run env PATH="$STUBS" /usr/bin/bash "$ROOT/modules/65-ai-cli/doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Node MISSING"* ]]
}
