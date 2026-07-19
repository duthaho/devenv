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
  for tool in mise direnv devbox brew apt-get dnf pacman sudo curl; do
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
  # Force a clean fake /proc so WSL detection in lib/os.sh doesn't fire.
  export DEVENV_PROC="$TMP/proc"
  mkdir -p "$DEVENV_PROC"
  # Force devenv_distro to return unknown by pointing at an empty etc.
  export DEVENV_ETC="$TMP/etc"
  mkdir -p "$DEVENV_ETC"
}

@test "30-toolchains: skips install when binaries already present" {
  # All stubs respond with exit 0, simulating "already installed". The script's
  # `command -v X` check finds the stub on PATH, so it treats X as present.
  run bash "$ROOT/modules/30-toolchains/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"30-toolchains: done"* ]]
}

@test "30-toolchains: writes mise config when absent" {
  bash "$ROOT/modules/30-toolchains/run.sh" >/dev/null
  [ -f "$HOME/.config/mise/config.toml" ]
  grep -Eq '^node[[:space:]]*=[[:space:]]*"lts"' "$HOME/.config/mise/config.toml"
}

@test "30-toolchains: writes direnv use_mise.sh" {
  bash "$ROOT/modules/30-toolchains/run.sh" >/dev/null
  [ -f "$HOME/.config/direnv/lib/use_mise.sh" ]
}

@test "30-toolchains doctor: PASS when all present" {
  # Pre-create the mise config so doctor sees it.
  mkdir -p "$HOME/.config/mise"
  : > "$HOME/.config/mise/config.toml"
  run bash "$ROOT/modules/30-toolchains/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == PASS* ]]
}

@test "30-toolchains: DEVENV_LANGS filters mise config to chosen tools" {
  DEVENV_LANGS="node,go" bash "$ROOT/modules/30-toolchains/run.sh" >/dev/null
  cfg="$HOME/.config/mise/config.toml"
  [ -f "$cfg" ]
  grep -Eq '^node[[:space:]]*=' "$cfg"
  grep -Eq '^go[[:space:]]*='   "$cfg"
  # negatives via explicit status (a bare `! grep` is errexit-exempt in bats)
  run grep -Eq '^python[[:space:]]*=' "$cfg"; [ "$status" -ne 0 ]
  run grep -Eq '^rust[[:space:]]*='   "$cfg"; [ "$status" -ne 0 ]
  # non-[tools] sections preserved
  grep -q '\[settings\]' "$cfg"
  grep -Eq '^experimental[[:space:]]*=' "$cfg"
}

@test "30-toolchains: no DEVENV_LANGS keeps the full tool set" {
  bash "$ROOT/modules/30-toolchains/run.sh" >/dev/null
  cfg="$HOME/.config/mise/config.toml"
  for t in node python go rust; do grep -Eq "^$t[[:space:]]*=" "$cfg"; done
}
