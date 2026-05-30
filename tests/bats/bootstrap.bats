#!/usr/bin/env bats

load test_helper

_setup_fakerepo() {
  FAKEROOT="$TEST_TMP/fakerepo"
  mkdir -p "$FAKEROOT/lib" "$FAKEROOT/modules/00-aaa" "$FAKEROOT/modules/10-bbb"
  cp "$DEVENV_ROOT/lib/log.sh"     "$FAKEROOT/lib/"
  cp "$DEVENV_ROOT/lib/os.sh"      "$FAKEROOT/lib/"
  cp "$DEVENV_ROOT/lib/markers.sh" "$FAKEROOT/lib/"
  cp "$DEVENV_ROOT/lib/op.sh"      "$FAKEROOT/lib/"
  cp "$DEVENV_ROOT/lib/prompts.sh" "$FAKEROOT/lib/"
  cp "$DEVENV_ROOT/bootstrap.sh"   "$FAKEROOT/"
  chmod +x "$FAKEROOT/bootstrap.sh"

  cat > "$FAKEROOT/modules/00-aaa/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "ran 00-aaa" >> "$TEST_TMP/order.log"
EOF
  cat > "$FAKEROOT/modules/10-bbb/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "ran 10-bbb" >> "$TEST_TMP/order.log"
EOF
  chmod +x "$FAKEROOT/modules/00-aaa/run.sh" "$FAKEROOT/modules/10-bbb/run.sh"
}

@test "bootstrap runs modules in sorted order" {
  _setup_fakerepo
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh"
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [[ "${lines[0]}" = "ran 00-aaa" ]]
  [[ "${lines[1]}" = "ran 10-bbb" ]]
}

@test "bootstrap --only restricts to one module" {
  _setup_fakerepo
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" --only 10-bbb
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [ "${lines[0]}" = "ran 10-bbb" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "bootstrap --skip excludes a module" {
  _setup_fakerepo
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" --skip 00-aaa
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [ "${lines[0]}" = "ran 10-bbb" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "bootstrap writes a .done marker per module" {
  _setup_fakerepo
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ -f "$DEVENV_CACHE_DIR/00-aaa.done" ]
  [ -f "$DEVENV_CACHE_DIR/10-bbb.done" ]
}

@test "bootstrap second run is a no-op when markers fresh" {
  _setup_fakerepo
  env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" >/dev/null
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh"
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [ -z "$output" ]
}

@test "bootstrap --force re-runs even with markers" {
  _setup_fakerepo
  env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" >/dev/null
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" --force
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [ "${lines[0]}" = "ran 00-aaa" ]
  [ "${lines[1]}" = "ran 10-bbb" ]
}

@test "bootstrap --from skips earlier modules" {
  _setup_fakerepo
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh" --from 10-bbb
  [ "$status" -eq 0 ]
  run cat "$TEST_TMP/order.log"
  [ "${lines[0]}" = "ran 10-bbb" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "bootstrap fails fast when a module errors" {
  _setup_fakerepo
  cat > "$FAKEROOT/modules/10-bbb/run.sh" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
  chmod +x "$FAKEROOT/modules/10-bbb/run.sh"
  : > "$TEST_TMP/order.log"
  run env DEVENV_CACHE_DIR="$DEVENV_CACHE_DIR" TEST_TMP="$TEST_TMP" "$FAKEROOT/bootstrap.sh"
  [ "$status" -ne 0 ]
  [ -f "$DEVENV_CACHE_DIR/00-aaa.done" ]
  [ ! -f "$DEVENV_CACHE_DIR/10-bbb.done" ]
}
