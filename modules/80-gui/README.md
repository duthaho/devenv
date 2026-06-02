# 80-gui

Opt-in GUI app bundle. Off by default — set `DEVENV_GUI_ENABLED=1` to enable.

## Run

```bash
DEVENV_GUI_ENABLED=1 devenv up --only 80-gui
```

```powershell
$env:DEVENV_GUI_ENABLED = '1'; devenv up --only 80-gui
```

## Config

| OS | File | Method |
|---|---|---|
| macOS / Linuxbrew / WSL2 | `config/gui/Brewfile` | `brew bundle --file=<Brewfile>` |
| Windows | `config/gui/winget.json` | `winget import --import-file=<json>` |

Both ship as commented templates — hand-edit before enabling.

## Env

- `DEVENV_GUI_ENABLED=1` — opt in.
- `DEVENV_SKIP_GUI_INSTALL=1` — short-circuit even when enabled (CI uses this).
- `DEVENV_GUI_BREWFILE` / `DEVENV_GUI_WINGET_FILE` — override the config paths (tests use these).

## Idempotency

Both `brew bundle` and `winget import` are idempotent — already-installed apps are skipped on re-run.
