# devenv

[![ci](https://github.com/duthaho/devenv/actions/workflows/ci.yml/badge.svg)](https://github.com/duthaho/devenv/actions/workflows/ci.yml)

One-terminal-command bootstrap for a full development environment. Cross-platform: macOS, Linux, Windows + WSL2. Extends [duthaho/dotfiles](https://github.com/duthaho/dotfiles) with secrets, language toolchains, Docker baseline services, IDEs, and Claude Code tooling.

## Quickstart

**macOS / Linux / WSL2 (one-liner):**

```bash
curl -fsSL https://raw.githubusercontent.com/duthaho/devenv/main/install | bash
```

**Windows (PowerShell 7):**

```powershell
irm https://raw.githubusercontent.com/duthaho/devenv/main/install.ps1 | iex
```

**Requirements:** bash 5+ or PowerShell 7+, `git`, and internet access. macOS uses Homebrew; Windows uses winget (preinstalled on Windows 11).

The installer clones `devenv` to `~/.local/share/devenv` (Unix) or `%LOCALAPPDATA%\devenv` (Windows), then runs every module in `modules/` in order. You'll be prompted once during `10-1password` to enable 1Password CLI integration and the SSH agent — after that, secrets are fetched on demand via `op`.

## Daily commands

```
devenv up                       re-run bootstrap (idempotent)
devenv up --only 10-1password   run just this module
devenv up --force               ignore .done markers
devenv doctor                   cross-platform Environment health summary + per-module checks
devenv help                     usage
```

`devenv doctor` leads with an **Environment** section — a cross-platform
(macOS / Linux / Windows+WSL2) health summary of the host wiring: OS/distro
detection, WSL↔Windows interop, `mise`/`direnv` shell hooks, tool shims on
`PATH`, 1Password reachability, and the SSH agent — each reported `PASS`/`WARN`/`FAIL`
(only `FAIL` sets a nonzero exit). The per-module checks follow underneath.

## Modules

| Module          | Purpose                                                                       | Platforms                              |
| --------------- | ----------------------------------------------------------------------------- | -------------------------------------- |
| `00-base`       | Package managers + `git`, `jq`, `gum`                                         | all                                    |
| `10-1password`  | 1Password app + CLI + SSH agent                                               | all                                    |
| `20-dotfiles`   | Clone + run [duthaho/dotfiles](https://github.com/duthaho/dotfiles) bootstrap | all                                    |
| `30-toolchains` | `mise` + `direnv` everywhere, `devbox` on Unix-family                         | all (devbox skipped on native Windows) |
| `40-docker`     | Docker engine + `devenv` network + baseline compose stack                     | all                                    |
| `50-ide`        | VS Code + Cursor + extension list + settings overlay                          | all (Linux: install warn-and-skip)     |
| `60-claude`     | Claude Code CLI + MCP servers + plugin packs                                  | all (requires npm from 30-toolchains)  |
| `70-repos`      | Clone configured project repos + run per-repo setup                           | all                                    |
| `80-gui`        | Opt-in GUI app bundle (Brewfile / winget.json)                                | mac/Linux/Windows (off by default)     |

## Configuration

| Path                     | Used by    | Purpose                                                          |
| ------------------------ | ---------- | ---------------------------------------------------------------- |
| `config/repos.txt`       | `70-repos` | Repos to clone — one per line: `remote [\| path [\| setup-cmd]]` |
| `config/gui/Brewfile`    | `80-gui`   | GUI casks on macOS/Linux/WSL                                     |
| `config/gui/winget.json` | `80-gui`   | GUI apps on Windows                                              |

`80-gui` is opt-in — set `DEVENV_GUI_ENABLED=1` to run it. Each module's `README.md` documents its env var overrides.

## Services

After `devenv up`, the baseline Docker stack runs on the shared `devenv` network:

| Service  | Host (in-network) | Host (localhost)                  | User  | Password    |
| -------- | ----------------- | --------------------------------- | ----- | ----------- |
| Postgres | `postgres.devenv` | `localhost:5432`                  | `dev` | `dev`       |
| MySQL    | `mysql.devenv`    | `localhost:3306`                  | `dev` | `dev`       |
| Redis    | `redis.devenv`    | `localhost:6379`                  | —     | —           |
| Mailpit  | `mailpit.devenv`  | UI `localhost:8025`, SMTP `:1025` | —     | —           |
| MinIO    | `minio.devenv`    | API `:9000`, UI `:9001`           | `dev` | `devsecret` |
| Adminer  | `adminer.devenv`  | `localhost:8080`                  | —     | —           |

Optional profiles: `aws` (LocalStack), `search` (OpenSearch + Dashboards), `vectors` (Qdrant), `queues` (RabbitMQ + Redpanda), `analytics` (ClickHouse), `observability` (Jaeger + Prometheus + Grafana + Loki + OTel), `alt-db` (Mongo), `auth` (Keycloak).

```bash
devenv services up                     # default profile
devenv services up search observability
devenv services status
devenv services init postgres myapp    # CREATE DATABASE myapp_dev
devenv services down
devenv services nuke --yes             # wipe all volumes
```

`devenv services status` prints a `SERVICE / STATE / READY` table. `READY`
reflects each service's Docker healthcheck — `healthy`, `starting`, or
`unhealthy` — or `no-probe` for a running service that defines no healthcheck.
The command exits non-zero if any service is `starting`, `unhealthy`, or not
running (a `no-probe` service passes), so it can gate scripts and wait-loops.

Per-machine extensions: drop a `compose.local.yml` at `~/.devenv/services/compose.local.yml` — it merges on top of the baseline automatically.

## Development

```bash
./tests/run.sh        # bats unit tests
./tests/run.ps1       # Pester unit tests
```

CI runs lint (ShellCheck + PSScriptAnalyzer), unit tests, and a smoke bootstrap on ubuntu-latest, macos-latest, and windows-latest on every PR and weekly.

## License

[MIT](LICENSE).
