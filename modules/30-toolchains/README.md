# 30-toolchains

Installs mise + direnv on every OS, plus devbox on macOS / Linux / WSL.

## Behavior

- **mise** — polyglot toolchain manager. Global defaults in `~/.config/mise/config.toml`.
- **direnv** — per-directory env loader. `~/.config/direnv/lib/use_mise.sh` shipped for `use mise` in `.envrc`.
- **devbox** — Nix-based per-project envs. **Native Windows skipped** (no Nix); use WSL.

## Inputs

- `DEVENV_LANGS` (optional) — comma-separated subset of the `[tools]` keys in
  `mise.config.toml` (e.g. `node,go`). When set, the generated
  `~/.config/mise/config.toml` includes only those tools (versions and other
  sections unchanged). Normally set for you by the first-run menu
  (`devenv up --reconfigure`); unset installs the full default set.

## Outputs

- `~/.config/mise/config.toml` (only if absent).
- `~/.config/direnv/lib/use_mise.sh`.
- `~/.cache/devenv/30-toolchains.done`.
