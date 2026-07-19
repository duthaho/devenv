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

# Install a docker stub that emits JSONL for `ps` and exits with $2 for it.
# Usage: status_stub <exit-code> <jsonl-line> [<jsonl-line> ...]
status_stub() {
  local rc="$1"; shift
  {
    printf '#!/usr/bin/env bash\n'
    printf 'for a in "$@"; do\n'
    printf '  if [ "$a" = ps ]; then\n'
    local line
    for line in "$@"; do
      printf "    printf '%%s\\\\n' %q\n" "$line"
    done
    printf '    exit %s\n' "$rc"
    printf '  fi\n'
    printf 'done\n'
    printf 'exit 0\n'
  } > "$STUBS/docker"
  chmod +x "$STUBS/docker"
}

@test "services status renders SERVICE/STATE/READY table with health mapping" {
  status_stub 0 \
    '{"Service":"postgres","State":"running","Health":"healthy"}' \
    '{"Service":"mailpit","State":"running","Health":""}' \
    '{"Service":"minio","State":"running","Health":"starting"}'
  run bash "$ROOT/bin/devenv" services status
  [[ "$output" == *"SERVICE"*"STATE"*"READY"* ]]
  [[ "$output" =~ postgres[[:space:]]+running[[:space:]]+healthy ]]
  [[ "$output" =~ mailpit[[:space:]]+running[[:space:]]+no-probe ]]
  [[ "$output" =~ minio[[:space:]]+running[[:space:]]+starting ]]
}

@test "services status exits 0 when all services healthy or no-probe" {
  status_stub 0 \
    '{"Service":"postgres","State":"running","Health":"healthy"}' \
    '{"Service":"mailpit","State":"running","Health":""}'
  run bash "$ROOT/bin/devenv" services status
  [ "$status" -eq 0 ]
}

@test "services status exits non-zero when a service is unhealthy" {
  status_stub 0 \
    '{"Service":"postgres","State":"running","Health":"healthy"}' \
    '{"Service":"redis","State":"running","Health":"unhealthy"}'
  run bash "$ROOT/bin/devenv" services status
  [ "$status" -ne 0 ]
}

@test "services status exits non-zero when a service is still starting" {
  status_stub 0 \
    '{"Service":"minio","State":"running","Health":"starting"}'
  run bash "$ROOT/bin/devenv" services status
  [ "$status" -ne 0 ]
}

@test "services status with no running services exits 0 with a notice" {
  status_stub 0   # ps succeeds, emits nothing
  run bash "$ROOT/bin/devenv" services status
  [ "$status" -eq 0 ]
  [[ "$output" == *"No services running"* ]]
}

@test "services status propagates a docker ps failure (not masked as empty)" {
  status_stub 1   # ps fails, emits nothing
  run bash "$ROOT/bin/devenv" services status
  [ "$status" -ne 0 ]
  [[ "$output" != *"No services running"* ]]
}

@test "CLI invoked via symlink resolves lib paths correctly" {
  mkdir -p "$TEST_TMP/bin"
  ln -s "$ROOT/bin/devenv" "$TEST_TMP/bin/devenv"
  [ -L "$TEST_TMP/bin/devenv" ] || skip "ln -s did not produce a real symlink on this platform"
  run bash "$TEST_TMP/bin/devenv" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: devenv"* ]]
}
