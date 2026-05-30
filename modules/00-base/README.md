# 00-base

Installs platform package managers and the minimal CLI cluster every later module depends on.

## What it does

- **macOS:** installs Homebrew if missing; `brew install jq gum`.
- **Linux (apt):** `sudo apt-get update && sudo apt-get install -y curl git jq` + installs `gum` via the Charm apt repo.
- **Linux (dnf):** `sudo dnf install -y curl git jq` + Charm rpm repo for `gum`.
- **Linux (arch):** `sudo pacman -S --needed --noconfirm curl git jq gum`.
- **Windows:** verifies `winget` is available; `winget install --silent --accept-source-agreements --accept-package-agreements Git.Git GitHub.cli stedolan.jq charmbracelet.gum`.

## What it does NOT do

- Install language toolchains (that's `30-toolchains`).
- Install Docker (that's `40-docker`).

## Inputs

None.

## Outputs

`~/.cache/devenv/00-base.done` on success.
