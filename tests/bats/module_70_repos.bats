#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/git" <<EOF
#!/usr/bin/env bash
echo "git \$@" >> "$TEST_TMP/calls.log"
if [ "\$1" = "clone" ]; then
  for a in "\$@"; do last="\$a"; done
  mkdir -p "\$last/.git"
fi
exit 0
EOF
  chmod +x "$STUBS/git"
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME/code"
}

@test "70-repos: skips when DEVENV_SKIP_REPO_CLONE=1" {
  DEVENV_SKIP_REPO_CLONE=1 run bash "$ROOT/modules/70-repos/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"70-repos: skipped"* ]]
  [ ! -f "$TEST_TMP/calls.log" ]
}

@test "70-repos: no-op when repos.txt is empty" {
  : > "$TEST_TMP/empty.txt"
  DEVENV_REPOS_FILE="$TEST_TMP/empty.txt" run bash "$ROOT/modules/70-repos/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"70-repos: done"* ]]
  [ ! -f "$TEST_TMP/calls.log" ] || ! grep -q "git clone" "$TEST_TMP/calls.log"
}

@test "70-repos: clones configured repos and runs setup" {
  cat > "$TEST_TMP/repos.txt" <<EOF
# header
https://github.com/x/alpha.git
https://github.com/x/beta.git | $TEST_TMP/beta-out | echo beta-setup > $TEST_TMP/beta.out
EOF
  DEVENV_REPOS_FILE="$TEST_TMP/repos.txt" bash "$ROOT/modules/70-repos/run.sh" >/dev/null
  grep -q "git clone --depth 1 https://github.com/x/alpha.git $HOME/code/alpha" "$TEST_TMP/calls.log"
  grep -q "git clone --depth 1 https://github.com/x/beta.git $TEST_TMP/beta-out" "$TEST_TMP/calls.log"
  [ -f "$TEST_TMP/beta.out" ]
}
