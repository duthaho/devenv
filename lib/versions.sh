#!/usr/bin/env bash
# External CLI manifest helpers. Source me; do not exec.

_devenv_versions_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_devenv_versions_file() { printf '%s\n' "${DEVENV_TOOL_VERSIONS_FILE:-$_devenv_versions_root/config/tool-versions.txt}"; }

devenv_tool_get() {
  local tool="$1" field="$2" key line
  key="${tool}.${field}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    [ "${line%%=*}" = "$key" ] && { printf '%s\n' "${line#*=}"; return 0; }
  done < "$(_devenv_versions_file)"
  printf 'E_MISSING %s\n' "$key" >&2; return 1
}

devenv_tool_manifest_lines() {
  local module="$1" line tool
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    tool="${line%%.*}"
    [ "$(devenv_tool_get "$tool" module 2>/dev/null || true)" = "$module" ] && printf '%s\n' "$line"
  done < "$(_devenv_versions_file)"
}

devenv_tool_validate() {
  local line n=0 key tool field err=0 tools=() seen='|' modules="$_devenv_versions_root/modules"
  [ -r "$( _devenv_versions_file )" ] || { printf 'E_MISSING manifest\n' >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    n=$((n + 1)); [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    if ! [[ "$line" =~ ^[a-z0-9-]+\.[a-z0-9._-]+=[^[:space:]]*$ ]]; then printf 'E_SYNTAX line %s\n' "$n" >&2; err=1; continue; fi
    key="${line%%=*}"
    tool="${key%%.*}"
    field="${key#*.}"
    if [[ "$seen" == *"|$key|"* ]]; then
      printf 'E_DUPLICATE %s\n' "$key" >&2; err=1
    fi
    seen+="$key|"
    case "$field" in
      module|source|package|version|sha256.linux-x86_64|sha256.linux-aarch64|sha256.macos|sha256.windows) ;;
      *) printf 'E_UNKNOWN_FIELD %s\n' "$key" >&2; err=1 ;;
    esac
    [[ " ${tools[*]} " == *" $tool "* ]] || tools+=("$tool")
  done < "$(_devenv_versions_file)"
  for tool in "${tools[@]}"; do
    local module source version package has_sha=0 artifact sha
    module="$(devenv_tool_get "$tool" module 2>/dev/null || true)"
    source="$(devenv_tool_get "$tool" source 2>/dev/null || true)"
    version="$(devenv_tool_get "$tool" version 2>/dev/null || true)"
    package="$(devenv_tool_get "$tool" package 2>/dev/null || true)"
    [ -n "$module" ] || { printf 'E_MISSING %s.module\n' "$tool" >&2; err=1; }; [ -d "$modules/$module" ] || { printf 'E_BAD_MODULE %s\n' "$tool" >&2; err=1; }
    [ -n "$source" ] || { printf 'E_MISSING %s.source\n' "$tool" >&2; err=1; }; [[ "$source" == npm || "$source" == release || "$source" == repo ]] || { printf 'E_BAD_SOURCE %s\n' "$tool" >&2; err=1; }
    [ -n "$version" ] || { printf 'E_MISSING %s.version\n' "$tool" >&2; err=1; }
    if [ "$source" = repo ]; then
      [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] || { printf 'E_BAD_VERSION %s\n' "$tool" >&2; err=1; }
    else
      [[ "$version" == latest || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'E_BAD_VERSION %s\n' "$tool" >&2; err=1; }
    fi
    [ "$source" != npm ] || [ -n "$package" ] || { printf 'E_MISSING %s.package\n' "$tool" >&2; err=1; }
    for artifact in linux-x86_64 linux-aarch64 macos windows; do sha="$(devenv_tool_get "$tool" "sha256.$artifact" 2>/dev/null || true)"; [ -z "$sha" ] || has_sha=1; done
    [ "$version" != latest ] || [ "$has_sha" = 0 ] || { printf 'E_SHA_ON_LATEST %s\n' "$tool" >&2; err=1; }
    [ "$source" != npm ] || [ "$has_sha" = 0 ] || { printf 'E_SHA_ON_NPM %s\n' "$tool" >&2; err=1; }
    [ "$source" != repo ] || [ "$has_sha" = 0 ] || { printf 'E_SHA_ON_REPO %s\n' "$tool" >&2; err=1; }
    if [ "$source" = release ] && [ "$version" != latest ]; then for artifact in linux-x86_64 linux-aarch64 macos windows; do sha="$(devenv_tool_get "$tool" "sha256.$artifact" 2>/dev/null || true)"; [ -n "$sha" ] || { printf 'E_MISSING_SHA %s.%s\n' "$tool" "$artifact" >&2; err=1; }; [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { printf 'E_BAD_SHA %s.%s\n' "$tool" "$artifact" >&2; err=1; }; done; fi
  done
  return "$err"
}

devenv_npm_spec() { local p v; p="$(devenv_tool_get "$1" package)"; v="$(devenv_tool_get "$1" version)"; [ "$v" = latest ] && printf '%s\n' "$p" || printf '%s@%s\n' "$p" "$v"; }
devenv_awscli_url() { local v; v="$(devenv_tool_get awscli version)"; case "$1" in linux-x86_64) [ "$v" = latest ] && printf '%s\n' 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' || printf 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64-%s.zip\n' "$v";; linux-aarch64) [ "$v" = latest ] && printf '%s\n' 'https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip' || printf 'https://awscli.amazonaws.com/awscli-exe-linux-aarch64-%s.zip\n' "$v";; macos) [ "$v" = latest ] && printf '%s\n' 'https://awscli.amazonaws.com/AWSCLIV2.pkg' || printf 'https://awscli.amazonaws.com/AWSCLIV2-%s.pkg\n' "$v";; windows) [ "$v" = latest ] && printf '%s\n' 'https://awscli.amazonaws.com/AWSCLIV2.msi' || printf 'https://awscli.amazonaws.com/AWSCLIV2-%s.msi\n' "$v";; esac; }
devenv_verify_sha256() {
  local file="$1" tool="$2" artifact="$3" v sha got
  v="$(devenv_tool_get "$tool" version)"
  [ "$v" = latest ] && return 0
  sha="$(devenv_tool_get "$tool" "sha256.$artifact")"
  if command -v sha256sum >/dev/null 2>&1; then got="$(sha256sum "$file" | awk '{print $1}')"; else got="$(shasum -a 256 "$file" | awk '{print $1}')"; fi
  [ "$got" = "$sha" ] || { rm -f "$file"; printf 'E_BAD_SHA %s.%s\n' "$tool" "$artifact" >&2; return 1; }
}
devenv_tool_drift() { local v installed got; v="$(devenv_tool_get "$1" version)"; installed="$2"; [ "$v" = latest ] && return 0; got="$(printf '%s\n' "$installed" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"; [ "$got" = "$v" ] || printf 'pinned %s, installed %s\n' "$v" "${got:-unknown}"; }
