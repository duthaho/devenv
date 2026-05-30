# devenv

[![ci](https://github.com/duthaho/devenv/actions/workflows/ci.yml/badge.svg)](https://github.com/duthaho/devenv/actions/workflows/ci.yml)

One-terminal-command bootstrap for a full development environment. Cross-platform: macOS, Linux, Windows + WSL2. Extends [duthaho/dotfiles](https://github.com/duthaho/dotfiles) with secrets, language toolchains, Docker baseline services, IDEs, and Claude Code tooling.

> **Status:** Phase 1 (MVP). Currently ships `00-base`, `10-1password`, and `20-dotfiles`. Later phases add `30-toolchains`, `40-docker`, `50-ide`, `60-claude`, `70-repos`, and `80-gui`.

## Quickstart

**macOS / Linux / WSL2 (one-liner):**

```bash
curl -fsSL https://raw.githubusercontent.com/duthaho/devenv/main/install | sh
```

**Windows (PowerShell 7):**

```powershell
irm https://raw.githubusercontent.com/duthaho/devenv/main/install.ps1 | iex
```

What it does:

1. Clones `devenv` to `~/.local/share/devenv` (Unix) or `%LOCALAPPDATA%\devenv` (Windows).
2. Runs `00-base` — installs Homebrew/winget packages and `jq`, `gum`, `git`.
3. Runs `10-1password` — installs 1Password desktop + CLI, walks you through signin, enables the SSH agent.
4. Runs `20-dotfiles` — clones [duthaho/dotfiles](https://github.com/duthaho/dotfiles) and runs its bootstrap.

You'll be prompted once during `10-1password` to enable 1Password CLI integration and the SSH agent. After that, every other secret is fetched on demand via `op`.

## Daily commands

```
devenv up                       re-run bootstrap (idempotent)
devenv up --only 10-1password   run just this module
devenv up --force               ignore .done markers
devenv doctor                   per-module health check
devenv help                     usage
```

## Modules (Phase 1)

| Module | Purpose | Platforms |
|---|---|---|
| `00-base` | Package managers + `git`, `jq`, `gum` | all |
| `10-1password` | 1Password app + CLI + SSH agent | all |
| `20-dotfiles` | Clone + run [duthaho/dotfiles](https://github.com/duthaho/dotfiles) bootstrap | all |

## Development

```bash
./tests/run.sh        # bats unit tests
./tests/run.ps1       # Pester unit tests
```

CI runs lint (ShellCheck + PSScriptAnalyzer), unit tests, and a smoke bootstrap on ubuntu-latest, macos-latest, and windows-latest on every PR and weekly.

## License

[MIT](LICENSE).
