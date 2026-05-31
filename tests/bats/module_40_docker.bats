#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  TMP="$TEST_TMP"
  STUBS="$TMP/stubs"
  mkdir -p "$STUBS"
  # Default docker stub: always succeeds (info, network inspect, compose, etc).
  cat > "$STUBS/docker" <<EOF
#!/usr/bin/env bash
echo "[docker] \$@" >> "$TMP/calls.log"
case "\$1" in
  info|network|compose) exit 0 ;;
esac
exit 0
EOF
  chmod +x "$STUBS/docker"
  for tool in curl sudo brew apt-get systemctl getent usermod; do
    cat > "$STUBS/$tool" <<EOF
#!/usr/bin/env bash
echo "[stub:$tool] \$@" >> "$TMP/calls.log"
exit 0
EOF
    chmod +x "$STUBS/$tool"
  done
  export PATH="$STUBS:$PATH"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export DEVENV_SERVICES_AUTOSTART=0
  # USER may be unset in Git Bash; the Linux branch of run.sh references it
  # under `set -u`, so we provide a safe default.
  export USER="${USER:-tester}"
  # Force run.sh into the linux branch (override Cygwin/MSYS OSTYPE on Windows hosts).
  export OSTYPE=linux-gnu
  # Make sure WSL detection doesn't fire via /proc/version.
  export DEVENV_PROC="$TMP/proc"
  mkdir -p "$DEVENV_PROC"
}

@test "40-docker: creates devenv network on Linux when absent" {
  # Force docker network inspect to fail (so we hit the create branch).
  cat > "$STUBS/docker" <<EOF
#!/usr/bin/env bash
echo "[docker] \$@" >> "$TMP/calls.log"
case "\$1" in
  network)
    if [ "\$2" = inspect ]; then exit 1; fi
    exit 0
    ;;
esac
exit 0
EOF
  chmod +x "$STUBS/docker"
  run bash "$ROOT/modules/40-docker/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'network create devenv' "$TMP/calls.log"
  [[ "$output" == *"40-docker: done"* ]]
}

@test "40-docker: skips network create when present" {
  run bash "$ROOT/modules/40-docker/run.sh"
  [ "$status" -eq 0 ]
  ! grep -q 'network create devenv' "$TMP/calls.log"
}

@test "40-docker: autostart skipped when DEVENV_SERVICES_AUTOSTART=0" {
  DEVENV_SERVICES_AUTOSTART=0 run bash "$ROOT/modules/40-docker/run.sh"
  [ "$status" -eq 0 ]
  ! grep -q 'compose .* up -d' "$TMP/calls.log"
}

@test "40-docker doctor: PASS when stubs report success" {
  run bash "$ROOT/modules/40-docker/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}
