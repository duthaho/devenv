#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  STUBS="$TEST_TMP/stubs"
  mkdir -p "$STUBS"
  for tool in code cursor brew apt-get dnf pacman sudo curl; do
    cat > "$STUBS/$tool" <<EOF
#!/usr/bin/env bash
echo "[stub:$tool] \$@" >> "$TEST_TMP/calls.log"
exit 0
EOF
    chmod +x "$STUBS/$tool"
  done
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
  export DEVENV_PROC="$TEST_TMP/proc"; mkdir -p "$DEVENV_PROC"
  export DEVENV_ETC="$TEST_TMP/etc";  mkdir -p "$DEVENV_ETC"
  export DEVENV_SKIP_CODE_INSTALL=1
}

@test "50-ide: completes when code+cursor already present" {
  run bash "$ROOT/modules/50-ide/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"50-ide: done"* ]]
}

@test "50-ide: installs configured vscode extensions" {
  printf 'ms-python.python\n' > "$ROOT/config/ide/vscode-extensions.txt.test"
  DEVENV_VSCODE_EXT_FILE="$ROOT/config/ide/vscode-extensions.txt.test" bash "$ROOT/modules/50-ide/run.sh" >/dev/null
  rm -f "$ROOT/config/ide/vscode-extensions.txt.test"
  grep -q -- '--install-extension ms-python.python' "$TEST_TMP/calls.log"
}

@test "50-ide: merges vscode-settings.json overlay into user settings" {
  bash "$ROOT/modules/50-ide/run.sh" >/dev/null
  case "$(uname -s)" in
    Darwin) settings="$HOME/Library/Application Support/Code/User/settings.json" ;;
    *)      settings="$HOME/.config/Code/User/settings.json" ;;
  esac
  [ -f "$settings" ]
  grep -q '"editor.formatOnSave"' "$settings"
}
