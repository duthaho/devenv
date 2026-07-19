#!/usr/bin/env bats

load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  export DEVENV_CACHE_DIR="$TEST_TMP/cache"
  mkdir -p "$DEVENV_CACHE_DIR"
  : "${DEVENV_ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  # shellcheck disable=SC1091
  . "$DEVENV_ROOT/lib/log.sh"
  # shellcheck disable=SC1091
  . "$DEVENV_ROOT/lib/markers.sh"
  # shellcheck disable=SC1091
  . "$DEVENV_ROOT/lib/menu.sh"
  STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export PATH="$STUBS:$PATH"
  # default: a gum stub exists (present)
  printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/gum"; chmod +x "$STUBS/gum"
  # a mise.config.toml fixture
  MISE_CFG="$TEST_TMP/mise.config.toml"
  cat > "$MISE_CFG" <<'EOF'
# comment
[tools]
node    = "lts"
python  = "3.13"
go      = "1.24"
rust    = "stable"

[settings]
experimental = true
EOF
}

teardown() { [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"; }

@test "devenv_menu_langs_available lists [tools] keys" {
  run devenv_menu_langs_available "$MISE_CFG"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "node" ]
  [ "${lines[1]}" = "python" ]
  [ "${lines[2]}" = "go" ]
  [ "${lines[3]}" = "rust" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "should_show is false under DEVENV_NON_INTERACTIVE even with --reconfigure" {
  DEVENV_NON_INTERACTIVE=1 run devenv_menu_should_show 1
  [ "$status" -ne 0 ]
}

@test "should_show is false when gum is absent" {
  rm -f "$STUBS/gum"
  # Constrain PATH to the (now gum-less) stubs dir so the system gum can't be found.
  PATH="$STUBS" run devenv_menu_should_show 1
  [ "$status" -ne 0 ]
}

@test "should_show is true with reconfigure=1 and gum present" {
  run devenv_menu_should_show 1
  [ "$status" -eq 0 ]
}

@test "should_show is false on a non-first run (markers present, no reconfigure)" {
  touch "$DEVENV_CACHE_DIR/00-base.done"
  run devenv_menu_should_show 0
  [ "$status" -ne 0 ]
}
