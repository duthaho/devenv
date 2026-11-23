#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export BASH_BIN="$(command -v bash)"
  export CHMOD_BIN="$(command -v chmod)"
  export DIRNAME_BIN="$(command -v dirname)"
  export HEAD_BIN="$(command -v head)"
  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  stub_tool head '"$HEAD_BIN" "$@"'
  export DEVENV_PLATFORM_KUBECTL=0 DEVENV_PLATFORM_HELM=0 DEVENV_PLATFORM_OPENTOFU=0
}

stub_tool() {
  local name="$1" body="$2"
  printf '#!%s\n%s\n' "$BASH_BIN" "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

@test "45-platform-cli: installs only selected kubectl through Homebrew" {
  export DEVENV_PLATFORM_KUBECTL=1
  stub_tool brew 'echo "brew $*" >> "$TEST_TMP/calls.log"; printf "#!%s\\necho clientVersion: v1.34.0\\n" "$BASH_BIN" > "$STUBS/kubectl"; "$CHMOD_BIN" +x "$STUBS/kubectl"'

  run env OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install kubectl' "$TEST_TMP/calls.log"
  [[ "$output" == *'45-platform-cli: done'* ]]
}

@test "45-platform-cli: installs only selected Helm through Homebrew" {
  export DEVENV_PLATFORM_HELM=1
  stub_tool brew 'echo "brew $*" >> "$TEST_TMP/calls.log"; printf "#!%s\\necho v3.17.0\\n" "$BASH_BIN" > "$STUBS/helm"; "$CHMOD_BIN" +x "$STUBS/helm"'

  run env OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install helm' "$TEST_TMP/calls.log"
}

@test "45-platform-cli: installs only selected OpenTofu through Homebrew" {
  export DEVENV_PLATFORM_OPENTOFU=1
  stub_tool brew 'echo "brew $*" >> "$TEST_TMP/calls.log"; printf "#!%s\\necho OpenTofu v1.9.0\\n" "$BASH_BIN" > "$STUBS/tofu"; "$CHMOD_BIN" +x "$STUBS/tofu"'

  run env OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install opentofu' "$TEST_TMP/calls.log"
}

@test "45-platform-cli: does not install until a tool is selected" {
  stub_tool brew 'exit 1'
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'45-platform-cli skipped'* ]]
}

@test "45-platform-cli: module skip prevents selected tool installation" {
  export DEVENV_PLATFORM_KUBECTL=1 DEVENV_SKIP_PLATFORM_CLI_INSTALL=1
  stub_tool brew 'exit 99'
  run env OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'DEVENV_SKIP_PLATFORM_CLI_INSTALL'* ]]
}

@test "45-platform-cli: selected install does not create kubeconfig state" {
  export DEVENV_PLATFORM_KUBECTL=1
  local test_home="$TEST_TMP/home"
  mkdir -p "$test_home"
  stub_tool brew 'printf "#!%s\\necho clientVersion: v1.34.0\\n" "$BASH_BIN" > "$STUBS/kubectl"; "$CHMOD_BIN" +x "$STUBS/kubectl"'

  run env HOME="$test_home" OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$test_home/.kube" ]
}

@test "45-platform-cli: selected tools are idempotent" {
  export DEVENV_PLATFORM_KUBECTL=1 DEVENV_PLATFORM_HELM=1 DEVENV_PLATFORM_OPENTOFU=1
  stub_tool kubectl 'echo clientVersion: v1.34.0'
  stub_tool helm 'echo v3.17.0'
  stub_tool tofu 'echo OpenTofu v1.9.0'

  run env PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'already installed'* ]]
}

@test "45-platform-cli: uses official Kubernetes, Helm and OpenTofu repositories" {
  run grep -F 'https://pkgs.k8s.io/core:/stable:/v${KUBECTL_REPO_MINOR}/deb/Release.key' "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'https://packages.buildkite.com/helm-linux/helm-debian/gpgkey' "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'https://packages.opentofu.org/opentofu/tofu/any/' "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'https://packages.opentofu.org/opentofu/tofu/gpgkey' "$ROOT/modules/45-platform-cli/run.sh"
  [ "$status" -eq 0 ]
}

@test "45-platform-cli doctor: reports disabled tools independently" {
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/45-platform-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'kubectl not installed (opt-in disabled'* ]]
  [[ "$output" == *'Helm not installed (opt-in disabled'* ]]
  [[ "$output" == *'OpenTofu not installed (opt-in disabled'* ]]
}
