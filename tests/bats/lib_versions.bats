#!/usr/bin/env bats
load test_helper

setup() { TEST_TMP="$(mktemp -d)"; export TEST_TMP; export DEVENV_CACHE_DIR="$TEST_TMP/cache"; mkdir -p "$DEVENV_CACHE_DIR"; guard_network; }

@test "pwsh_path converts MSYS paths with cygpath" {
  stub_cmd cygpath "test \"\$1\" = \"-m\" && test \"\$2\" = \"/d/a/devenv/devenv/lib/versions.ps1\" || exit 1; printf '%s\\n' 'D:/a/devenv/devenv/lib/versions.ps1'"
  [ "$(pwsh_path "/d/a/devenv/devenv/lib/versions.ps1")" = "D:/a/devenv/devenv/lib/versions.ps1" ]
}

@test "tool version manifest validates and returns npm specs" {
  run bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate; devenv_npm_spec codex; devenv_npm_spec wrangler'
  [ "$status" -eq 0 ]
  [[ "$output" == *"@openai/codex"* ]]
  [[ "$output" == *"wrangler"* ]]
}

@test "repo source accepts an X.Y minor" {
  run bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate; devenv_tool_get kubectl version'
  [ "$status" -eq 0 ]
  [ "$output" = '1.37' ]
}

@test "pinned test manifest changes specs and AWS URL without module edits" {
  cp "$DEVENV_ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
  portable_sed_in_place 's/codex.version=latest/codex.version=0.1.2/; s/wrangler.version=latest/wrangler.version=3.4.5/; s/awscli.version=latest/awscli.version=2.9.9/' "$TEST_TMP/versions.txt"
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

@test "validator rejects every documented manifest error" {
  local good_sha='0000000000000000000000000000000000000000000000000000000000000000'
  local code mutation
  while IFS='|' read -r code mutation; do
    cp "$DEVENV_ROOT/config/tool-versions.txt" "$TEST_TMP/versions.txt"
    case "$mutation" in
      syntax) printf '%s\n' 'not a manifest entry' >> "$TEST_TMP/versions.txt" ;;
      duplicate) printf '%s\n' 'codex.version=latest' >> "$TEST_TMP/versions.txt" ;;
      missing) portable_sed_in_place '/codex.package=/d' "$TEST_TMP/versions.txt" ;;
      bad_module) portable_sed_in_place 's/codex.module=65-ai-cli/codex.module=missing/' "$TEST_TMP/versions.txt" ;;
      bad_source) portable_sed_in_place 's/codex.source=npm/codex.source=registry/' "$TEST_TMP/versions.txt" ;;
      bad_version) portable_sed_in_place 's/codex.version=latest/codex.version=v1.2.3/' "$TEST_TMP/versions.txt" ;;
      missing_sha) portable_sed_in_place 's/awscli.version=latest/awscli.version=2.9.9/' "$TEST_TMP/versions.txt" ;;
      bad_sha) portable_sed_in_place 's/awscli.version=latest/awscli.version=2.9.9/' "$TEST_TMP/versions.txt"; printf '%s\n' "awscli.sha256.linux-x86_64=bad" "awscli.sha256.linux-aarch64=$good_sha" "awscli.sha256.macos=$good_sha" "awscli.sha256.windows=$good_sha" >> "$TEST_TMP/versions.txt" ;;
      sha_latest) printf '%s\n' "awscli.sha256.windows=$good_sha" >> "$TEST_TMP/versions.txt" ;;
      sha_npm) printf '%s\n' "codex.sha256.windows=$good_sha" >> "$TEST_TMP/versions.txt" ;;
      repo_latest) portable_sed_in_place 's/kubectl.version=1.37/kubectl.version=latest/' "$TEST_TMP/versions.txt" ;;
      repo_semver) portable_sed_in_place 's/kubectl.version=1.37/kubectl.version=1.37.0/' "$TEST_TMP/versions.txt" ;;
      sha_repo) printf '%s\n' "kubectl.sha256.windows=$good_sha" >> "$TEST_TMP/versions.txt" ;;
    esac
    run env DEVENV_TOOL_VERSIONS_FILE="$TEST_TMP/versions.txt" bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_validate'
    [ "$status" -ne 0 ]
    [[ "$output" == *"$code"* ]]
  done <<'CASES'
E_SYNTAX|syntax
E_DUPLICATE|duplicate
E_MISSING codex.package|missing
E_BAD_MODULE codex|bad_module
E_BAD_SOURCE codex|bad_source
E_BAD_VERSION codex|bad_version
E_MISSING_SHA awscli.linux-x86_64|missing_sha
E_BAD_SHA awscli.linux-x86_64|bad_sha
E_SHA_ON_LATEST awscli|sha_latest
E_SHA_ON_NPM codex|sha_npm
E_BAD_VERSION kubectl|repo_latest
E_BAD_VERSION kubectl|repo_semver
E_SHA_ON_REPO kubectl|sha_repo
CASES
}

@test "Bash tool settings match PowerShell for every manifest key" {
  command -v pwsh >/dev/null || skip "pwsh not installed"
  local key tool field bash_value ps_value ps_versions
  ps_versions="$(pwsh_path "$DEVENV_ROOT/lib/versions.ps1")"
  while IFS='=' read -r key _; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    tool="${key%%.*}"; field="${key#*.}"
    bash_value="$(bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_get "$1" "$2"' _ "$tool" "$field")"
    ps_value="$(pwsh -NoProfile -Command ". '$ps_versions'; Get-DevenvToolSetting '$tool' '$field'")"
    [ "$bash_value" = "$ps_value" ]
  done < "$DEVENV_ROOT/config/tool-versions.txt"
}
