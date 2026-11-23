#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TEST_TMP="$(mktemp -d)"
  : "${ROOT:=$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)}"
  export STUBS="$TEST_TMP/stubs"; mkdir -p "$STUBS"
  export PATH="$STUBS:$PATH"
  export BASH_BIN="$(command -v bash)"
  export CHMOD_BIN="$(command -v chmod)"
  export DIRNAME_BIN="$(command -v dirname)"
  export HEAD_BIN="$(command -v head)"
  export MKDIR_BIN="$(command -v mkdir)"
  export HOME="$TEST_TMP/home"; mkdir -p "$HOME"
  export DEVENV_CLOUD_WRANGLER=1
  export DEVENV_CLOUD_CLOUDFLARED=1
  export DEVENV_CLOUD_AWS=0
}

stub_tool() {
  local name="$1" body="$2"
  printf '#!%s\n%s\n' "$BASH_BIN" "$body" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

@test "35-cloud-cli: installs only selected Wrangler through npm" {
  export DEVENV_CLOUD_CLOUDFLARED=0
  stub_tool node 'exit 0'
  stub_tool npm 'echo "npm $*" >> "$TEST_TMP/calls.log"; printf "#!/usr/bin/env bash\\necho wrangler 4.0.0\\n" > "$STUBS/wrangler"; chmod +x "$STUBS/wrangler"'

  run env PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'npm install -g wrangler' "$TEST_TMP/calls.log"
  [[ "$output" == *'35-cloud-cli: done'* ]]
}

@test "35-cloud-cli: installs only selected cloudflared with Homebrew" {
  export DEVENV_CLOUD_WRANGLER=0
  stub_tool brew 'echo "brew $*" >> "$TEST_TMP/calls.log"; printf "#!%s\\necho cloudflared 2026.1.0\\n" "$BASH_BIN" > "$STUBS/cloudflared"; "$CHMOD_BIN" +x "$STUBS/cloudflared"'

  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  stub_tool head '"$HEAD_BIN" "$@"'
  run env OSTYPE=darwin PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q 'brew install cloudflared' "$TEST_TMP/calls.log"
}

@test "35-cloud-cli: does not install until a tool is selected" {
  unset DEVENV_CLOUD_WRANGLER DEVENV_CLOUD_CLOUDFLARED DEVENV_CLOUD_AWS
  stub_tool npm 'exit 1'
  stub_tool brew 'exit 1'

  run bash "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'35-cloud-cli skipped'* ]]
}

@test "35-cloud-cli: AWS CLI v2 is idempotent" {
  export DEVENV_CLOUD_WRANGLER=0 DEVENV_CLOUD_CLOUDFLARED=0 DEVENV_CLOUD_AWS=1
  stub_tool aws 'echo aws-cli/2.25.0 Python/3.12 Linux/6 exe/x86_64; exit 0'

  run env PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'already installed'* ]]
}

@test "35-cloud-cli: AWS CLI v1 is warned about without replacement" {
  export DEVENV_CLOUD_WRANGLER=0 DEVENV_CLOUD_CLOUDFLARED=0 DEVENV_CLOUD_AWS=1
  stub_tool aws 'echo aws-cli/1.32.0 Python/3.11 Linux/6 botocore/1.34.0; exit 0'

  run env PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'v1 detected'* ]]
}

@test "35-cloud-cli: AWS Linux installer verifies the signed official bundle" {
  run grep -F 'awscli-exe-linux-${arch}.zip' "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'gpg --batch --homedir "$gpg_home" --verify "$signature" "$archive"' "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'A631 0ACC 4672 475C' "$ROOT/modules/35-cloud-cli/README.md"
  [ "$status" -eq 0 ]
}

@test "35-cloud-cli: installs AWS CLI v2 after Linux signature verification" {
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) skip "Linux installer mock: MSYS cannot chmod the gnupg homedir" ;; esac
  export DEVENV_CLOUD_WRANGLER=0 DEVENV_CLOUD_CLOUDFLARED=0 DEVENV_CLOUD_AWS=1
  stub_tool uname 'echo x86_64'
  stub_tool aws 'exit 127'
  stub_tool curl 'echo "curl $*" >> "$TEST_TMP/calls.log"; while [ "$#" -gt 0 ]; do if [ "$1" = "-o" ]; then shift; : > "$1"; fi; shift; done'
  stub_tool gpg 'echo "gpg $*" >> "$TEST_TMP/calls.log"; exit 0'
  stub_tool record_aws_install 'echo "aws/install $*" >> "$TEST_TMP/calls.log"; printf "%s\\n" "#!/usr/bin/env bash" "echo aws-cli/2.25.0 Python/3.12 Linux/6 exe/x86_64" > "$STUBS/aws"; "$CHMOD_BIN" +x "$STUBS/aws"'
  stub_tool unzip 'echo "unzip $*" >> "$TEST_TMP/calls.log"; dest=""; while [ "$#" -gt 0 ]; do if [ "$1" = "-d" ]; then shift; dest="$1"; fi; shift; done; "$MKDIR_BIN" -p "$dest/aws"; printf "%s\\n" "#!/usr/bin/env bash" "record_aws_install \\\$@" > "$dest/aws/install"; "$CHMOD_BIN" +x "$dest/aws/install"'
  stub_tool sudo 'echo "sudo $*" >> "$TEST_TMP/calls.log"; "$@"'

  run env OSTYPE=linux-gnu PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  grep -q -- '--verify' "$TEST_TMP/calls.log"
  grep -q -- '/aws/install --update' "$TEST_TMP/calls.log"
  [[ "$output" == *'AWS CLI aws-cli/2.25.0'* ]]
}

@test "35-cloud-cli: stops before AWS installation when Linux signature verification fails" {
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) skip "Linux installer mock: MSYS cannot chmod the gnupg homedir" ;; esac
  export DEVENV_CLOUD_WRANGLER=0 DEVENV_CLOUD_CLOUDFLARED=0 DEVENV_CLOUD_AWS=1
  stub_tool uname 'echo x86_64'
  stub_tool aws 'exit 127'
  stub_tool curl 'echo "curl $*" >> "$TEST_TMP/calls.log"; while [ "$#" -gt 0 ]; do if [ "$1" = "-o" ]; then shift; : > "$1"; fi; shift; done'
  stub_tool gpg 'echo "gpg $*" >> "$TEST_TMP/calls.log"; case "$*" in *--verify*) exit 1 ;; esac; exit 0'
  stub_tool unzip 'echo "unzip $*" >> "$TEST_TMP/calls.log"; exit 99'
  stub_tool sudo 'echo "sudo $*" >> "$TEST_TMP/calls.log"; exit 99'

  run env OSTYPE=linux-gnu PATH="$STUBS:$PATH" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -ne 0 ]
  grep -q -- '--verify' "$TEST_TMP/calls.log"
  ! grep -q '^unzip ' "$TEST_TMP/calls.log" || false
  ! grep -q '^sudo ' "$TEST_TMP/calls.log" || false
  ! grep -q '/aws/install' "$TEST_TMP/calls.log" || false
}

@test "35-cloud-cli: uses Cloudflare's v2 apt key and scoped keyring" {
  run grep -F 'https://pkg.cloudflare.com/cloudflare-public-v2.gpg' "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
  run grep -F 'signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg' "$ROOT/modules/35-cloud-cli/run.sh"
  [ "$status" -eq 0 ]
}

@test "35-cloud-cli doctor: reports missing Node for selected Wrangler" {
  export DEVENV_CLOUD_CLOUDFLARED=0
  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Node MISSING'* ]]
}

@test "35-cloud-cli doctor: distinguishes AWS CLI v1" {
  export DEVENV_CLOUD_WRANGLER=0 DEVENV_CLOUD_CLOUDFLARED=0 DEVENV_CLOUD_AWS=1
  stub_tool aws 'echo aws-cli/1.32.0 Python/3.11 Linux/6 botocore/1.34.0; exit 0'
  stub_tool dirname '"$DIRNAME_BIN" "$@"'
  stub_tool head '"$HEAD_BIN" "$@"'

  run env PATH="$STUBS" "$BASH_BIN" "$ROOT/modules/35-cloud-cli/doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'AWS CLI v1 installed'* ]]
}
