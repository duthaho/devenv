#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib/log.sh"
# shellcheck disable=SC1091
. "$HERE/lib/os.sh"
# shellcheck disable=SC1091
. "$HERE/lib/markers.sh"

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [flags]

Flags:
  --only m1,m2         only run these modules (comma-separated names)
  --skip m1,m2         skip these modules
  --from <name>        run starting from this module
  --force              ignore .done markers; re-run every selected module
  --non-interactive    set DEVENV_NON_INTERACTIVE=1 so prompts auto-default
  -h, --help           print this help and exit
EOF
}

ONLY=""
SKIP=""
FROM=""
FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)            ONLY="$2"; shift 2 ;;
    --skip)            SKIP="$2"; shift 2 ;;
    --from)            FROM="$2"; shift 2 ;;
    --force)           FORCE=1; shift ;;
    --non-interactive) export DEVENV_NON_INTERACTIVE=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 log_err "Unknown flag: $1"; usage; exit 2 ;;
  esac
done

_in_csv() { local needle="$1" csv="$2"; case ",$csv," in *",$needle,"*) return 0 ;; *) return 1 ;; esac; }

OS="$(devenv_os)"
log_info "devenv bootstrap on $OS"

MODULES_DIR="$HERE/modules"
[ -d "$MODULES_DIR" ] || { log_err "modules/ not found at $MODULES_DIR"; exit 1; }

mods=()
while IFS= read -r d; do mods+=("$d"); done < <(find "$MODULES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

reached_from=0
[ -z "$FROM" ] && reached_from=1

failed=0
for mod_dir in "${mods[@]}"; do
  name="$(basename "$mod_dir")"

  if [ -n "$FROM" ] && [ "$reached_from" -eq 0 ]; then
    if [ "$name" = "$FROM" ]; then reached_from=1; else log_dbg "skip (before --from): $name"; continue; fi
  fi
  if [ -n "$ONLY" ] && ! _in_csv "$name" "$ONLY"; then log_dbg "skip (not in --only): $name"; continue; fi
  if [ -n "$SKIP" ] &&   _in_csv "$name" "$SKIP"; then log_info "skip (in --skip): $name"; continue; fi

  runner="run.sh"

  if [ ! -f "$mod_dir/$runner" ]; then
    log_warn "$name: no $runner found, skipping"
    continue
  fi

  sha="$(module_sha "$mod_dir" || echo "")"
  if [ "$FORCE" -eq 0 ] && [ -n "$sha" ] && is_done "$name" "$sha"; then
    log_info "$name: up-to-date (cached)"
    continue
  fi

  log_info "==> $name"
  if ! bash "$mod_dir/$runner"; then failed=1; log_err "$name failed"; break; fi

  [ -n "$sha" ] && mark_done "$name" "$sha"
done

if [ "$failed" -ne 0 ]; then
  log_err "bootstrap aborted. Inspect ~/.cache/devenv/*.log for details, then re-run."
  exit 1
fi

link_cli() {
  local cli="$HERE/bin/devenv"
  local link="$HOME/.local/bin/devenv"
  [ -x "$cli" ] || { log_warn "bin/devenv not executable; skipping CLI link"; return 0; }
  mkdir -p "$HOME/.local/bin"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$cli" ]; then
    log_info "devenv CLI link already at $link"
  elif [ -e "$link" ] && [ ! -L "$link" ]; then
    log_warn "$link exists and is not a symlink; refusing to overwrite. Remove it and re-run."
  else
    ln -sf "$cli" "$link"
    log_info "Linked $link -> $cli"
  fi
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) log_warn "~/.local/bin is not on \$PATH. Add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
}
link_cli

log_info "bootstrap complete"
