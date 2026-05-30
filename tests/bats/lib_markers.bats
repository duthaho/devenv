#!/usr/bin/env bats

load test_helper

@test "marker_path uses DEVENV_CACHE_DIR" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && marker_path 00-base"
  [ "$status" -eq 0 ]
  [ "$output" = "$DEVENV_CACHE_DIR/00-base.done" ]
}

@test "module_sha is stable across calls" {
  local mod="$TEST_TMP/modfake"
  mkdir -p "$mod"
  echo 'run' > "$mod/run.sh"
  echo 'doc' > "$mod/doctor.sh"
  echo 'r'   > "$mod/README.md"
  local a b
  a="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  b="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  [ -n "$a" ]
  [ "$a" = "$b" ]
}

@test "module_sha changes when run.sh changes" {
  local mod="$TEST_TMP/modfake"
  mkdir -p "$mod"
  echo 'run-v1' > "$mod/run.sh"
  echo 'doc' > "$mod/doctor.sh"
  echo 'r'   > "$mod/README.md"
  local a b
  a="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  echo 'run-v2' > "$mod/run.sh"
  b="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  [ "$a" != "$b" ]
}

@test "is_done returns nonzero when marker missing" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && is_done 00-base abc"
  [ "$status" -ne 0 ]
}

@test "mark_done + is_done round-trip" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123 && is_done 00-base abc123"
  [ "$status" -eq 0 ]
}

@test "is_done fails when sha mismatches" {
  bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123"
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && is_done 00-base different"
  [ "$status" -ne 0 ]
}

@test "clear_done removes marker" {
  bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123"
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && clear_done 00-base && is_done 00-base abc123"
  [ "$status" -ne 0 ]
}
