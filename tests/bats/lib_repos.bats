#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  source "$ROOT/lib/repos.sh"
}

@test "devenv_repos_default_path: strips .git and prefixes ~/code" {
  HOME="$TEST_TMP/home" run devenv_repos_default_path "git@github.com:duthaho/duthaho.dev.git"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_TMP/home/code/duthaho.dev" ]
}

@test "devenv_repos_default_path: works for https remotes without .git suffix" {
  HOME="$TEST_TMP/home" run devenv_repos_default_path "https://github.com/duthaho/dotfiles"
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_TMP/home/code/dotfiles" ]
}

@test "devenv_repos_parse_file: emits tab-separated remote/path/setup, ignoring comments and blanks" {
  cat > "$TEST_TMP/repos.txt" <<EOF
# header
git@github.com:a/one.git
https://github.com/b/two.git | /custom/path

git@github.com:c/three.git | ~/code/three | mise install && devbox install
EOF
  HOME="$TEST_TMP/home" run devenv_repos_parse_file "$TEST_TMP/repos.txt"
  [ "$status" -eq 0 ]
  # one: no path, no setup
  [[ "${lines[0]}" == $'git@github.com:a/one.git\t'*'/home/code/one'$'\t' ]]
  # two: explicit path, no setup
  [[ "${lines[1]}" == $'https://github.com/b/two.git\t/custom/path\t' ]]
  # three: explicit path + setup
  [[ "${lines[2]}" == $'git@github.com:c/three.git\t'*'/home/code/three'$'\tmise install && devbox install' ]]
  [ "${#lines[@]}" -eq 3 ]
}

@test "devenv_repos_parse_file: returns empty on missing file" {
  run devenv_repos_parse_file "$TEST_TMP/missing.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "devenv_repos_sync_one: clones missing repo, fetches existing repo, runs setup" {
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  cat > "$STUBS/git" <<EOF
#!/usr/bin/env bash
echo "git \$@" >> "$TEST_TMP/calls.log"
# Simulate clone by creating the target .git when invoked with "clone".
if [ "\$1" = "clone" ]; then
  for a in "\$@"; do
    last="\$a"
  done
  mkdir -p "\$last/.git"
fi
exit 0
EOF
  chmod +x "$STUBS/git"
  export PATH="$STUBS:$PATH"

  # Existing repo: pre-create .git so the branch picks "fetch".
  mkdir -p "$TEST_TMP/exists/.git"
  devenv_repos_sync_one "https://github.com/x/exists.git" "$TEST_TMP/exists" "echo setup-existing > $TEST_TMP/setup-existing.out"

  # Missing repo: target doesn't exist yet.
  devenv_repos_sync_one "https://github.com/x/missing.git" "$TEST_TMP/missing" "echo setup-missing > $TEST_TMP/setup-missing.out"

  grep -q "git -C $TEST_TMP/exists fetch" "$TEST_TMP/calls.log"
  grep -q "git clone --depth 1 https://github.com/x/missing.git $TEST_TMP/missing" "$TEST_TMP/calls.log"
  [ -f "$TEST_TMP/setup-existing.out" ]
  [ -f "$TEST_TMP/setup-missing.out" ]
}
