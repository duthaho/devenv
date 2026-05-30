#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

@test "devenv_os returns mac on Darwin" {
  run bash -c "OSTYPE=darwin23; source $DEVENV_ROOT/lib/os.sh && devenv_os"
  [ "$status" -eq 0 ]
  [ "$output" = "mac" ]
}

@test "devenv_os returns linux on plain Linux" {
  mkdir -p "$TEST_TMP/etc"
  echo 'ID=ubuntu' > "$TEST_TMP/etc/os-release"
  run bash -c "OSTYPE=linux-gnu; DEVENV_ETC=$TEST_TMP/etc; DEVENV_PROC=$TEST_TMP/noexist; source $DEVENV_ROOT/lib/os.sh && devenv_os"
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
}

@test "devenv_os returns wsl when /proc/version contains microsoft" {
  mkdir -p "$TEST_TMP/proc"
  echo 'Linux version 5.15 (microsoft@WSL)' > "$TEST_TMP/proc/version"
  run bash -c "OSTYPE=linux-gnu; DEVENV_PROC=$TEST_TMP/proc; source $DEVENV_ROOT/lib/os.sh && devenv_os"
  [ "$status" -eq 0 ]
  [ "$output" = "wsl" ]
}

@test "devenv_distro returns ubuntu when ID=ubuntu" {
  mkdir -p "$TEST_TMP/etc"
  echo 'ID=ubuntu' > "$TEST_TMP/etc/os-release"
  run bash -c "OSTYPE=linux-gnu; DEVENV_ETC=$TEST_TMP/etc; DEVENV_PROC=$TEST_TMP/noexist; source $DEVENV_ROOT/lib/os.sh && devenv_distro"
  [ "$status" -eq 0 ]
  [ "$output" = "ubuntu" ]
}

@test "devenv_distro returns empty on macOS" {
  run bash -c "OSTYPE=darwin23; source $DEVENV_ROOT/lib/os.sh && devenv_distro"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "devenv_distro returns unknown for foo distro" {
  mkdir -p "$TEST_TMP/etc"
  echo 'ID=foo' > "$TEST_TMP/etc/os-release"
  run bash -c "OSTYPE=linux-gnu; DEVENV_ETC=$TEST_TMP/etc; DEVENV_PROC=$TEST_TMP/noexist; source $DEVENV_ROOT/lib/os.sh && devenv_distro"
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}
