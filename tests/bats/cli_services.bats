#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  STUBS="$TEST_TMP/stubs"
  mkdir -p "$STUBS"
  cat > "$STUBS/docker" <<EOF
#!/usr/bin/env bash
echo "docker \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
  chmod +x "$STUBS/docker"
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
}

@test "services help prints usage" {
  run bash "$ROOT/bin/devenv" services help
  [ "$status" -eq 0 ]
  [[ "$output" == *"services up [profiles"* ]]
}

@test "services up calls docker compose with default profile" {
  run bash "$ROOT/bin/devenv" services up
  [ "$status" -eq 0 ]
  grep -q -- '--profile default' "$TEST_TMP/calls.log"
  grep -q -- 'up -d' "$TEST_TMP/calls.log"
}

@test "services up <a> <b> uses both profiles" {
  bash "$ROOT/bin/devenv" services up search vectors >/dev/null
  grep -q -- '--profile search' "$TEST_TMP/calls.log"
  grep -q -- '--profile vectors' "$TEST_TMP/calls.log"
}

@test "services init postgres myapp issues CREATE DATABASE myapp_dev" {
  bash "$ROOT/bin/devenv" services init postgres myapp >/dev/null
  grep -q 'CREATE DATABASE myapp_dev' "$TEST_TMP/calls.log"
}

@test "services init unsupported service exits 2" {
  run bash "$ROOT/bin/devenv" services init banana myapp
  [ "$status" -eq 2 ]
}

@test "services nuke without --yes exits 2" {
  run bash "$ROOT/bin/devenv" services nuke
  [ "$status" -eq 2 ]
}

@test "services nuke --yes calls compose down -v" {
  bash "$ROOT/bin/devenv" services nuke --yes >/dev/null
  grep -q -- 'down -v' "$TEST_TMP/calls.log"
}

@test "services down passes every known profile to compose" {
  bash "$ROOT/bin/devenv" services down >/dev/null
  for p in default aws search vectors queues analytics observability alt-db auth; do
    grep -q -- "--profile $p" "$TEST_TMP/calls.log" || { echo "missing --profile $p"; return 1; }
  done
  grep -q -- ' down' "$TEST_TMP/calls.log"
}

@test "services nuke --yes passes every known profile to compose" {
  bash "$ROOT/bin/devenv" services nuke --yes >/dev/null
  for p in default aws search vectors queues analytics observability alt-db auth; do
    grep -q -- "--profile $p" "$TEST_TMP/calls.log" || { echo "missing --profile $p"; return 1; }
  done
}

@test "CLI invoked via symlink resolves lib paths correctly" {
  mkdir -p "$TEST_TMP/bin"
  ln -s "$ROOT/bin/devenv" "$TEST_TMP/bin/devenv"
  [ -L "$TEST_TMP/bin/devenv" ] || skip "ln -s did not produce a real symlink on this platform"
  run bash "$TEST_TMP/bin/devenv" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: devenv"* ]]
}
