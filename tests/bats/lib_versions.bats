#!/usr/bin/env bats
load test_helper

setup() { TEST_TMP="$(mktemp -d)"; export TEST_TMP; export DEVENV_CACHE_DIR="$TEST_TMP/cache"; mkdir -p "$DEVENV_CACHE_DIR"; guard_network; }

@test "tool version manifest validates and returns npm specs" {
  run bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate; devenv_npm_spec codex; devenv_npm_spec wrangler'
  [ "$status" -eq 0 ]
  [[ "$output" == *"@openai/codex"* ]]
  [[ "$output" == *"wrangler"* ]]
}

@test "pinned test manifest changes specs and AWS URL without module edits" {
  cp "$DEVENV_ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  sed -i 's/codex.version=latest/codex.version=0.1.2/; s/wrangler.version=latest/wrangler.version=3.4.5/; s/awscli.version=latest/awscli.version=2.9.9/' "$TEST_TMP/versions.txt"
  printf '%s\n' 'awscli.sha256.linux-x86_64=0000000000000000000000000000000000000000000000000000000000000000' 'awscli.sha256.linux-aarch64=0000000000000000000000000000000000000000000000000000000000000000' 'awscli.sha256.macos=0000000000000000000000000000000000000000000000000000000000000000' 'awscli.sha256.windows=0000000000000000000000000000000000000000000000000000000000000000' >> "$TEST_TMP/versions.txt"
  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate; devenv_npm_spec codex; devenv_npm_spec wrangler; devenv_awscli_url windows'
  [ "$status" -eq 0 ]
  [[ "$output" == *"@openai/codex@0.1.2"* ]]
  [[ "$output" == *"wrangler@3.4.5"* ]]
  [[ "$output" == *"AWSCLIV2-2.9.9.msi"* ]]
}

@test "validator rejects unknown fields" {
  cp "$DEVENV_ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  printf '%s\n' 'codex.bad=value' >> "$TEST_TMP/versions.txt"
  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate'
  [ "$status" -ne 0 ]
  [[ "$output" == *"E_UNKNOWN_FIELD codex.bad"* ]]
}

@test "CRLF manifest has the same npm specification as LF" {
  sed 's/$/\r/' "$DEVENV_ROOT/config/tool-versions.txt" > "$TEST_TMP/versions-crlf.txt"
  run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions-crlf.txt" bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate; devenv_npm_spec codex'
  [ "$status" -eq 0 ]
  [ "$output" = '@openai/codex' ]
}
