#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

# Source lib/doctor.sh in a controlled subshell with env overrides.
# Usage: dsh '<extra env>' '<function call>'
dsh() {
  local env="$1" call="$2"
  bash -c "$env source '$DEVENV_ROOT/lib/doctor.sh' && $call"
}

# --- os check -------------------------------------------------------------

@test "devenv_dcheck_os returns PASS and names the host os" {
  run dsh "OSTYPE=darwin23;" "devenv_dcheck_os"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
  [[ "$output" == *"os"* ]]
  [[ "$output" == *"mac"* ]]
}

@test "devenv_dcheck_os includes distro on linux" {
  mkdir -p "$TEST_TMP/etc"
  echo 'ID=ubuntu' > "$TEST_TMP/etc/os-release"
  run dsh "OSTYPE=linux-gnu; DEVENV_ETC=$TEST_TMP/etc; DEVENV_PROC=$TEST_TMP/noexist;" "devenv_dcheck_os"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux/ubuntu"* ]]
}

# --- aggregator -----------------------------------------------------------

@test "devenv_doctor_env prints an os line and returns 0 when all pass" {
  run dsh "OSTYPE=darwin23;" "devenv_doctor_env"
  [ "$status" -eq 0 ]
  [[ "$output" == *"os"* ]]
  [[ "$output" == *"PASS"* ]]
}
