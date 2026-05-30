#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats-core not installed. Install with: " >&2
  echo "  brew install bats-core   # macOS"               >&2
  echo "  sudo apt install bats    # Debian/Ubuntu"       >&2
  echo "  sudo pacman -S bats      # Arch"                >&2
  exit 1
fi

cd "$HERE/.."
exec bats --print-output-on-failure --recursive tests/bats
