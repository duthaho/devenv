#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  source "$ROOT/lib/gui.sh"
}

@test "devenv_gui_enabled: returns 1 by default" {
  unset DEVENV_GUI_ENABLED || true
  run devenv_gui_enabled
  [ "$status" -eq 1 ]
}

@test "devenv_gui_enabled: returns 0 when DEVENV_GUI_ENABLED=1" {
  DEVENV_GUI_ENABLED=1 run devenv_gui_enabled
  [ "$status" -eq 0 ]
}

@test "devenv_gui_has_entries: returns 1 on empty/all-comment Brewfile" {
  cat > "$TEST_TMP/Brewfile" <<EOF
# only comments
# cask "slack"
EOF
  run devenv_gui_has_entries "$TEST_TMP/Brewfile"
  [ "$status" -eq 1 ]
}

@test "devenv_gui_has_entries: returns 0 when at least one non-comment line" {
  cat > "$TEST_TMP/Brewfile" <<EOF
# header
cask "slack"
EOF
  run devenv_gui_has_entries "$TEST_TMP/Brewfile"
  [ "$status" -eq 0 ]
}

@test "devenv_gui_brew_bundle: calls brew bundle when entries present and brew on PATH" {
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
  chmod +x "$STUBS/brew"
  export PATH="$STUBS:$PATH"
  cat > "$TEST_TMP/Brewfile" <<EOF
cask "slack"
EOF
  run devenv_gui_brew_bundle "$TEST_TMP/Brewfile"
  [ "$status" -eq 0 ]
  grep -q "brew bundle --file=$TEST_TMP/Brewfile" "$TEST_TMP/calls.log"
}

@test "devenv_gui_brew_bundle: no-op when Brewfile is empty" {
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
  chmod +x "$STUBS/brew"
  export PATH="$STUBS:$PATH"
  cat > "$TEST_TMP/Brewfile" <<EOF
# all comments
EOF
  run devenv_gui_brew_bundle "$TEST_TMP/Brewfile"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_TMP/calls.log" ] || ! grep -q "brew bundle" "$TEST_TMP/calls.log"
}
