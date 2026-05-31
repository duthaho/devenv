# 40-docker

Installs Docker, creates the external `devenv` network, and optionally starts the baseline compose stack.

## Behavior

- **macOS / Windows:** Docker Desktop (brew cask / winget).
- **Linux:** `get.docker.com` convenience script + add user to `docker` group + enable systemd unit.
- **WSL:** expects Docker Desktop's WSL integration; falls back to in-WSL engine with a warning.
- Creates network `devenv` (external; shared across all per-project composes).
- Autostarts the `default` profile unless `DEVENV_SERVICES_AUTOSTART=0`.

## Inputs

- `DEVENV_SERVICES_AUTOSTART` (`1` default; `0` skips autostart).

## Outputs

- Docker network `devenv`.
- `~/.cache/devenv/40-docker.done`.

## Per-machine override

Drop a `compose.local.yml` at `~/.devenv/services/compose.local.yml` to extend / override the baseline.
