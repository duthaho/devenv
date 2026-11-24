#!/usr/bin/env bats

load test_helper

@test "marker_path uses DEVENV_CACHE_DIR" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && marker_path 00-base"
  [ "$status" -eq 0 ]
  [ "$output" = "$DEVENV_CACHE_DIR/00-base.done" ]
}

@test "module_sha is stable across calls" {
  local mod="$TEST_TMP/modfake"
  mkdir -p "$mod"
  echo 'run' > "$mod/run.sh"
  echo 'doc' > "$mod/doctor.sh"
  echo 'r'   > "$mod/README.md"
  local a b
  a="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  b="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  [ -n "$a" ]
  [ "$a" = "$b" ]
}

@test "module_sha changes when run.sh changes" {
  local mod="$TEST_TMP/modfake"
  mkdir -p "$mod"
  echo 'run-v1' > "$mod/run.sh"
  echo 'doc' > "$mod/doctor.sh"
  echo 'r'   > "$mod/README.md"
  local a b
  a="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  echo 'run-v2' > "$mod/run.sh"
  b="$(source $DEVENV_ROOT/lib/markers.sh; module_sha "$mod")"
  [ "$a" != "$b" ]
}

@test "manifest changes invalidate only its owning module and match PowerShell SHA" {
  command -v pwsh >/dev/null || skip "pwsh not installed"
  local manifest="$TEST_TMP/versions.txt"
  cp "$DEVENV_ROOT/config/tool-versions.txt" "$manifest"
  local ai cloud base ai_changed cloud_changed base_changed ps_sha bash_sha
  local ps_manifest ps_markers ps_module
  ai="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/65-ai-cli"')"
  cloud="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/35-cloud-cli"')"
  base="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/00-base"')"
  portable_sed_in_place 's/codex.version=latest/codex.version=0.1.2/' "$manifest"
  ai_changed="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/65-ai-cli"')"
  cloud_changed="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/35-cloud-cli"')"
  base_changed="$(DEVENV_TOOL_VERSIONS_FILE="$manifest" bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$DEVENV_ROOT/modules/00-base"')"
  [ "$ai" != "$ai_changed" ]; [ "$cloud" = "$cloud_changed" ]; [ "$base" = "$base_changed" ]
  ps_manifest="$(pwsh_path "$manifest")"
  ps_markers="$(pwsh_path "$DEVENV_ROOT/lib/markers.ps1")"
  ps_module="$(pwsh_path "$DEVENV_ROOT/modules/65-ai-cli")"
  ps_sha="$(DEVENV_TOOL_VERSIONS_FILE="$ps_manifest" pwsh -NoProfile -Command ". '$ps_markers'; Get-DevenvModuleSha '$ps_module'")"
  bash_sha="$ai_changed"
  [ "$bash_sha" = "$ps_sha" ]
}

@test "is_done returns nonzero when marker missing" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && is_done 00-base abc"
  [ "$status" -ne 0 ]
}

@test "mark_done + is_done round-trip" {
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123 && is_done 00-base abc123"
  [ "$status" -eq 0 ]
}

@test "is_done fails when sha mismatches" {
  bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123"
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && is_done 00-base different"
  [ "$status" -ne 0 ]
}

@test "clear_done removes marker" {
  bash -c "source $DEVENV_ROOT/lib/markers.sh && mark_done 00-base abc123"
  run bash -c "source $DEVENV_ROOT/lib/markers.sh && clear_done 00-base && is_done 00-base abc123"
  [ "$status" -ne 0 ]
}
