#!/usr/bin/env bash
# Shared bats helper — source from each .bats file.

# Repo root from this file's location.
DEVENV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DEVENV_ROOT

# A clean tmp dir per test.
setup() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  # Isolate marker cache so tests never touch the real user.
  export DEVENV_CACHE_DIR="$TEST_TMP/cache"
  mkdir -p "$DEVENV_CACHE_DIR"
}

teardown() {
  [ ! -e "$TEST_TMP/network.log" ] || { cat "$TEST_TMP/network.log" >&2; return 1; }
  [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

guard_network() {
  local guard="$TEST_TMP/network-guard" tool
  mkdir -p "$guard"
  for tool in curl wget npm brew winget; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "$TEST_TMP/network.log"\nexit 97\n' "$tool" > "$guard/$tool"
    chmod +x "$guard/$tool"
  done
  export PATH="$PATH:$guard"
}

# stub_cmd <name> <body> — prepends a script named <name> to PATH that runs <body>.
stub_cmd() {
  local name="$1" body="$2"
  local stubdir="$TEST_TMP/stubs"
  mkdir -p "$stubdir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$stubdir/$name"
  chmod +x "$stubdir/$name"
  export PATH="$stubdir:$PATH"
}

# BSD sed requires a backup suffix for in-place edits; GNU sed accepts it too.
portable_sed_in_place() {
  local expression="$1" file="$2"
  sed -i.bak "$expression" "$file" && rm -f "${file}.bak"
}

# pwsh on Windows cannot resolve MSYS paths passed by bats.
pwsh_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s\n' "$1"
  fi
}
