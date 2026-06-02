#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
  chmod +x "$STUBS/brew"
  export PATH="$STUBS:$PATH"
}

@test "80-gui: opt-in skip when DEVENV_GUI_ENABLED unset" {
  unset DEVENV_GUI_ENABLED || true
  run bash "$ROOT/modules/80-gui/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"80-gui: opt-in, skipped"* ]]
  [ ! -f "$TEST_TMP/calls.log" ]
}

@test "80-gui: ci skip when DEVENV_SKIP_GUI_INSTALL=1" {
  DEVENV_GUI_ENABLED=1 DEVENV_SKIP_GUI_INSTALL=1 run bash "$ROOT/modules/80-gui/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"80-gui: skipped"* ]]
  [ ! -f "$TEST_TMP/calls.log" ]
}

@test "80-gui: runs brew bundle when enabled and Brewfile has entries" {
  cat > "$TEST_TMP/Brewfile" <<EOF
cask "slack"
EOF
  DEVENV_GUI_ENABLED=1 DEVENV_GUI_BREWFILE="$TEST_TMP/Brewfile" \
    run bash "$ROOT/modules/80-gui/run.sh"
  [ "$status" -eq 0 ]
  grep -q "brew bundle --file=$TEST_TMP/Brewfile" "$TEST_TMP/calls.log"
  [[ "$output" == *"80-gui: done"* ]]
}

@test "80-gui: enabled but empty Brewfile completes without calling brew" {
  cat > "$TEST_TMP/Brewfile" <<EOF
# all comments
EOF
  DEVENV_GUI_ENABLED=1 DEVENV_GUI_BREWFILE="$TEST_TMP/Brewfile" \
    run bash "$ROOT/modules/80-gui/run.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_TMP/calls.log" ] || ! grep -q "brew bundle" "$TEST_TMP/calls.log"
  [[ "$output" == *"80-gui: done"* ]]
}
