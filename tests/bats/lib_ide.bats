#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  source "$ROOT/lib/ide.sh"
}

@test "devenv_ide_extensions_from_file: ignores comments and blanks" {
  cat > "$TEST_TMP/exts.txt" <<EOF
# header
ms-python.python

# blank above
eamodio.gitlens
EOF
  run devenv_ide_extensions_from_file "$TEST_TMP/exts.txt"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ms-python.python" ]
  [ "${lines[1]}" = "eamodio.gitlens" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "devenv_ide_extensions_from_file: returns empty on missing file" {
  run devenv_ide_extensions_from_file "$TEST_TMP/missing.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "devenv_ide_merge_settings: merges overlay on top of existing user settings" {
  cat > "$TEST_TMP/user.json" <<EOF
{ "editor.fontSize": 14, "editor.formatOnSave": false }
EOF
  cat > "$TEST_TMP/overlay.json" <<EOF
{ "editor.formatOnSave": true, "files.trimTrailingWhitespace": true }
EOF
  devenv_ide_merge_settings "$TEST_TMP/overlay.json" "$TEST_TMP/user.json"
  fs=$(jq -r '."editor.fontSize"' "$TEST_TMP/user.json")
  fos=$(jq -r '."editor.formatOnSave"' "$TEST_TMP/user.json")
  tt=$(jq -r '."files.trimTrailingWhitespace"' "$TEST_TMP/user.json")
  [ "$fs" = "14" ]
  [ "$fos" = "true" ]
  [ "$tt" = "true" ]
}

@test "devenv_ide_merge_settings: creates user.json when absent" {
  cat > "$TEST_TMP/overlay.json" <<EOF
{ "editor.formatOnSave": true }
EOF
  devenv_ide_merge_settings "$TEST_TMP/overlay.json" "$TEST_TMP/new.json"
  [ -f "$TEST_TMP/new.json" ]
  fos=$(jq -r '."editor.formatOnSave"' "$TEST_TMP/new.json")
  [ "$fos" = "true" ]
}

@test "devenv_ide_install_extensions: calls cli --install-extension once per id" {
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/fakecode" <<EOF
#!/usr/bin/env bash
echo "fakecode \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
  chmod +x "$STUBS/fakecode"
  export PATH="$STUBS:$PATH"
  cat > "$TEST_TMP/exts.txt" <<EOF
ms-python.python
eamodio.gitlens
EOF
  run devenv_ide_install_extensions fakecode "$TEST_TMP/exts.txt"
  [ "$status" -eq 0 ]
  grep -q -- '--install-extension ms-python.python --force' "$TEST_TMP/calls.log"
  grep -q -- '--install-extension eamodio.gitlens --force' "$TEST_TMP/calls.log"
}
