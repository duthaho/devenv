#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export PATH="$STUBS:$PATH"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME"
  export DEVENV_CLOUD_WRANGLER=1
  export DEVENV_CLOUD_CLOUDFLARED=1
}

stub_tool() {
  local name="$1" body="$2"
  printf '#!/usr/bin/bash\n%s\n' "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

@test "35-cloud-cli: installs only selected Wrangler through npm" {
  export DEVENV_CLOUD_CLOUDFLARED=0
  stub_tool node 'exit 0'
  stub_tool npm 'echo "npm $*" >> "$TEST_TMP/calls.log"; printf "#!/usr/bin/env bash\\necho wrangler 4.0.0\\n" > "$STUBS/wrangler"; chmod +x "$STUBS/wrangler"'

  run env PATH="$STUBS:/usr/bin:/bin" bash "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'npm install -g wrangler' "$TEST_TMP/calls.log"
  [[ "$output" == *'35-cloud-cli: done'* ]]
}

@test "35-cloud-cli: installs only selected cloudflared with Homebrew" {
  export DEVENV_CLOUD_WRANGLER=0
  stub_tool brew 'echo "brew $*" >> "$TEST_TMP/calls.log"; printf "#!/usr/bin/bash\\necho cloudflared 2026.1.0\\n" > "$STUBS/cloudflared"; /usr/bin/chmod +x "$STUBS/cloudflared"'

  stub_tool dirname '/usr/bin/dirname "$@"'
  stub_tool head '/usr/bin/head "$@"'
  run env OSTYPE=darwin PATH="$STUBS" /usr/bin/bash "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install cloudflared' "$TEST_TMP/calls.log"
}

@test "35-cloud-cli: does not install until a tool is selected" {
  unset DEVENV_CLOUD_WRANGLER DEVENV_CLOUD_CLOUDFLARED
  stub_tool npm 'exit 1'
  stub_tool brew 'exit 1'

  run bash "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'35-cloud-cli skipped'* ]]
}

@test "35-cloud-cli doctor: reports missing Node for selected Wrangler" {
  export DEVENV_CLOUD_CLOUDFLARED=0
  stub_tool dirname '/usr/bin/dirname "$@"'
  run env PATH="$STUBS" /usr/bin/bash "$ROOT/modules/35-cloud-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Node MISSING'* ]]
}
