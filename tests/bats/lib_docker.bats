#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  . "$ROOT/lib/docker.sh"
}

@test "devenv_compose_main_path resolves to repo's services/compose.yml" {
  run devenv_compose_main_path
  [ "$status" -eq 0 ]
  [[ "$output" == */services/compose.yml ]]
}

@test "devenv_compose_local_path resolves to ~/.devenv/services/compose.local.yml" {
  HOME=/tmp/fake-home run devenv_compose_local_path
  [ "$status" -eq 0 ]
  [ "$output" = "/tmp/fake-home/.devenv/services/compose.local.yml" ]
}

@test "devenv_compose_args includes -f main; adds -f local if file exists" {
  local fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.devenv/services"
  HOME="$fake_home" run devenv_compose_args
  [ "$status" -eq 0 ]
  [[ "$output" == *"-f $ROOT/services/compose.yml"* ]]
  [[ "$output" != *"compose.local.yml"* ]]

  : > "$fake_home/.devenv/services/compose.local.yml"
  HOME="$fake_home" run devenv_compose_args
  [[ "$output" == *"compose.local.yml"* ]]
}

@test "devenv_db_for_project returns <project>_dev" {
  run devenv_db_for_project myapp
  [ "$status" -eq 0 ]
  [ "$output" = "myapp_dev" ]
}
