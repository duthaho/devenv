#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  _common_setup
}

_common_setup() {
  TEST_TMP="$(mktemp -d)"
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  STUBS="$TEST_TMP/stubs"
  CALLS="$TEST_TMP/calls.log"
  ETC_DIR="$TEST_TMP/etc"
  mkdir -p "$STUBS" "$ETC_DIR"
  printf 'ID=ubuntu\n' > "$ETC_DIR/os-release"
  cat > "$STUBS/gh" <<'EOF'
#!/bin/bash
echo 'gh version 0.0.0'
EOF
  chmod +x "$STUBS/gh"
  for tool in sudo curl dpkg apt-get dnf pacman winget brew; do
    cat > "$STUBS/$tool" <<EOF
#!/bin/bash
echo "$tool \$*" >> "$CALLS"
if [ "\$1" = "tee" ]; then cat >/dev/null; fi
if [ "$tool" = "brew" ] && [ "\$1" = "list" ]; then exit 1; fi
exit 0
EOF
    chmod +x "$STUBS/$tool"
  done
  cat > "$STUBS/dirname" <<'EOF'
#!/bin/bash
printf '%s\n' "${1%/*}"
EOF
  chmod +x "$STUBS/dirname"
  cat > "$STUBS/cat" <<'EOF'
#!/bin/bash
while IFS= read -r _; do :; done
EOF
  chmod +x "$STUBS/cat"
  export DEVENV_ETC="$ETC_DIR"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "00-base: Debian installs gh from GitHub's apt repo and productivity tools" {
  run /usr/bin/env OSTYPE=linux-gnu DEVENV_SKIP_SHELL_PRODUCTIVITY=0 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'cli.github.com/packages/githubcli-archive-keyring.gpg' "$CALLS"
  grep -q 'apt-get install -y gh' "$CALLS"
  grep -q 'apt-get install -y --no-install-recommends fzf ripgrep bat zoxide' "$CALLS"
}

@test "00-base: Fedora uses the official GitHub rpm repository" {
  printf 'ID=fedora\n' > "$ETC_DIR/os-release"
  run /usr/bin/env OSTYPE=linux-gnu DEVENV_SKIP_SHELL_PRODUCTIVITY=0 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo' "$CALLS"
  grep -q 'dnf install -y gh --repo gh-cli' "$CALLS"
}

@test "00-base: Arch installs gh and productivity tools from pacman" {
  printf 'ID=arch\n' > "$ETC_DIR/os-release"
  run /usr/bin/env OSTYPE=linux-gnu DEVENV_SKIP_SHELL_PRODUCTIVITY=0 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'pacman -S --needed --noconfirm curl git jq gum gh' "$CALLS"
  grep -q 'pacman -S --needed --noconfirm fzf ripgrep bat zoxide' "$CALLS"
}

@test "00-base: macOS installs gh and productivity tools with Homebrew" {
  run /usr/bin/env OSTYPE=darwin22 DEVENV_SKIP_SHELL_PRODUCTIVITY=0 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install gh' "$CALLS"
  grep -q 'brew install zoxide' "$CALLS"
}

@test "00-base: Windows installs gh and the productivity bundle with winget" {
  run /usr/bin/env OSTYPE=msys DEVENV_SKIP_SHELL_PRODUCTIVITY=0 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'winget install .*GitHub.cli' "$CALLS"
  grep -q 'winget install .*BurntSushi.ripgrep.MSVC' "$CALLS"
}

@test "00-base: opt-out does not install any productivity tool" {
  run /usr/bin/env OSTYPE=linux-gnu DEVENV_SKIP_SHELL_PRODUCTIVITY=1 DEVENV_FORCE_GH_INSTALL=1 PATH="$STUBS" /bin/bash "$ROOT/modules/00-base/run.sh"
  [ "$status" -eq 0 ]
  ! grep -Eq 'fzf|ripgrep|bat|zoxide' "$CALLS"
  grep -q 'apt-get install -y gh' "$CALLS"
}
