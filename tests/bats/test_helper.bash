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
  [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
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
