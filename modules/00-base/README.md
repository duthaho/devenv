# 00-base

Installs platform package managers and the minimal CLI cluster every later module depends on.

## What it does

- **macOS:** installs Homebrew if missing; installs `jq`, `gum`, and [GitHub CLI](https://cli.github.com/manual/installation) (`gh`) with Homebrew.
- **Linux (apt):** installs `curl`, `git`, `jq`; installs `gum` from the Charm repo and `gh` from the [official GitHub CLI apt repository](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
- **Linux (dnf):** installs `curl`, `git`, `jq`; installs `gum` from the Charm repo and `gh` from the [official GitHub CLI rpm repository](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
- **Linux (arch):** installs `curl`, `git`, `jq`, `gum`, and `gh` from official Arch packages.
- **Windows:** verifies `winget` is available; installs `Git.Git`, `GitHub.cli`, `stedolan.jq`, `charmbracelet.gum`, and the shell productivity bundle.
- **Shell productivity (default):** installs `fzf`, `ripgrep` (`rg`), `bat`, and `zoxide` from the platform package manager. Set `DEVENV_SKIP_SHELL_PRODUCTIVITY=1` before bootstrap to opt out completely.

## What it does NOT do

- Install language toolchains (that's `30-toolchains`).
- Install Docker (that's `40-docker`).

## Inputs

- `DEVENV_SKIP_SHELL_PRODUCTIVITY=1` — skip all of `fzf`, `ripgrep`, `bat`, and `zoxide`.

On Debian and Ubuntu the `bat` package provides `batcat`. The module creates
`/usr/local/bin/bat` pointing to `batcat`, so documentation and shell usage are
consistent across operating systems.

Bootstrap never logs in to GitHub. `GH_TOKEN` is optional for later `gh` use.
The module doctor treats missing shell productivity tools as optional and labels
them `OPTIONAL-MISSING`; a missing `gh` remains a failure.

## Outputs

`~/.cache/devenv/00-base.done` on success.
