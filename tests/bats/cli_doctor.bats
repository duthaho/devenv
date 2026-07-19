#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
  export OP_MOCK=1
}

teardown() {
  [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

@test "doctor prints an Environment section then a Modules section" {
  run bash "$ROOT/bin/devenv" doctor
  [[ "$output" == *"Environment"* ]]
  [[ "$output" == *"Modules"* ]]
  [[ "$output" == *"os"* ]]
}

@test "doctor prints Environment before Modules" {
  run bash "$ROOT/bin/devenv" doctor
  env_line="$(printf '%s\n' "$output" | grep -n '^Environment' | head -1 | cut -d: -f1)"
  mod_line="$(printf '%s\n' "$output" | grep -n '^Modules' | head -1 | cut -d: -f1)"
  [ -n "$env_line" ]
  [ -n "$mod_line" ]
  [ "$env_line" -lt "$mod_line" ]
}

@test "doctor exits nonzero when checks fail in a bare environment" {
  # No toolchains installed under this fake HOME/PATH: module doctors + env
  # checks (shims) FAIL, so the overall result must be nonzero.
  run bash "$ROOT/bin/devenv" doctor
  [ "$status" -ne 0 ]
}
