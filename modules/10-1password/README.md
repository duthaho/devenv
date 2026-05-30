# 10-1password

Installs the 1Password `op` CLI. On Mac/Windows also installs the desktop app and wires its SSH agent into `~/.ssh/config.d/`.

## Behavior

- **macOS / Windows:** desktop + CLI. Manual step: sign in to the desktop app and enable **Settings → Developer → Integrate with 1Password CLI** + **Use the SSH agent**.
- **Linux / WSL:** CLI only. Signin via `eval "$(op signin)"` (interactive) or `OP_SERVICE_ACCOUNT_TOKEN` (Teams/Business plans).

## Inputs

- `OP_SERVICE_ACCOUNT_TOKEN` (optional).

## Outputs

- `~/.ssh/config.d/10-1password.conf` (Mac/Windows only).
- `~/.cache/devenv/10-1password.done` on success.
