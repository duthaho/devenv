# 30-toolchains

Installs mise + direnv on every OS, plus devbox on macOS / Linux / WSL.

## Behavior

- **mise** — polyglot toolchain manager. Global defaults in `~/.config/mise/config.toml`.
- **direnv** — per-directory env loader. `~/.config/direnv/lib/use_mise.sh` shipped for `use mise` in `.envrc`.
- **devbox** — Nix-based per-project envs. **Native Windows skipped** (no Nix); use WSL.

## Inputs

None.

## Outputs

- `~/.config/mise/config.toml` (only if absent).
- `~/.config/direnv/lib/use_mise.sh`.
- `~/.cache/devenv/30-toolchains.done`.
