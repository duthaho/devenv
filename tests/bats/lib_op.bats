#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

@test "op_available is true when op stub is on PATH" {
  stub_cmd op 'exit 0'
  run bash -c "source $DEVENV_ROOT/lib/op.sh && op_available"
  [ "$status" -eq 0 ]
}

@test "op_available is false when op is not on PATH" {
  run bash -c "PATH=/usr/bin:/bin source $DEVENV_ROOT/lib/op.sh && op_available"
  if command -v op >/dev/null 2>&1; then
    skip "host has 'op' globally installed"
  fi
  [ "$status" -ne 0 ]
}

@test "op_signed_in respects OP_MOCK=1" {
  run bash -c "OP_MOCK=1; export OP_MOCK; source $DEVENV_ROOT/lib/op.sh && op_signed_in"
  [ "$status" -eq 0 ]
}

@test "op_read returns mock-value when OP_MOCK=1" {
  run bash -c "OP_MOCK=1; export OP_MOCK; source $DEVENV_ROOT/lib/op.sh && op_read 'op://vault/item/field'"
  [ "$status" -eq 0 ]
  [ "$output" = "mock-value" ]
}

@test "op_inject copies file when OP_MOCK=1" {
  echo 'API_KEY={{ op://x/y/z }}' > "$TEST_TMP/in"
  run bash -c "OP_MOCK=1; export OP_MOCK; source $DEVENV_ROOT/lib/op.sh && op_inject '$TEST_TMP/in' '$TEST_TMP/out'"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/out" ]
  run cat "$TEST_TMP/out"
  [[ "$output" == *"op://x/y/z"* ]]
}

@test "op_require_signin succeeds when OP_MOCK=1" {
  run bash -c "OP_MOCK=1; export OP_MOCK; source $DEVENV_ROOT/lib/op.sh && op_require_signin"
  [ "$status" -eq 0 ]
}

@test "op_require_signin fails with retry hint when not signed in" {
  stub_cmd op 'exit 1'
  run --separate-stderr bash -c "source $DEVENV_ROOT/lib/op.sh && op_require_signin"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"op signin"* ]]
}
