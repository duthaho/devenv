#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

@test "log_info writes message to stderr with INFO prefix" {
  source "$DEVENV_ROOT/lib/log.sh"
  run --separate-stderr bash -c "source $DEVENV_ROOT/lib/log.sh && log_info hello"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"INFO"* ]]
  [[ "$stderr" == *"hello"* ]]
  [ -z "$output" ]   # stdout must be empty
}

@test "log_warn writes WARN prefix" {
  run --separate-stderr bash -c "source $DEVENV_ROOT/lib/log.sh && log_warn careful"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"WARN"* ]]
  [[ "$stderr" == *"careful"* ]]
}

@test "log_err writes ERROR prefix" {
  run --separate-stderr bash -c "source $DEVENV_ROOT/lib/log.sh && log_err nope"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"ERROR"* ]]
  [[ "$stderr" == *"nope"* ]]
}

@test "log_dbg is suppressed at default level" {
  run --separate-stderr bash -c "unset DEVENV_LOG_LEVEL; source $DEVENV_ROOT/lib/log.sh && log_dbg quiet"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "log_dbg fires when DEVENV_LOG_LEVEL=debug" {
  run --separate-stderr bash -c "export DEVENV_LOG_LEVEL=debug; source $DEVENV_ROOT/lib/log.sh && log_dbg loud"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"DEBUG"* ]]
  [[ "$stderr" == *"loud"* ]]
}

@test "log_info suppressed when DEVENV_LOG_LEVEL=error" {
  run --separate-stderr bash -c "export DEVENV_LOG_LEVEL=error; source $DEVENV_ROOT/lib/log.sh && log_info hush"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}
