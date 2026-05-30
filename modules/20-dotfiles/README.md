# 20-dotfiles

Clones [duthaho/dotfiles](https://github.com/duthaho/dotfiles) to `~/.dotfiles` (or `$DOTFILES_DIR`) and runs its bootstrap script non-interactively.

## What it does

1. `git clone git@github.com:duthaho/dotfiles.git ~/.dotfiles` (SSH via the 1P agent; HTTPS fallback for public clones).
2. If the repo already exists: `git -C ~/.dotfiles pull --ff-only`.
3. Runs `~/.dotfiles/bootstrap.sh --non-interactive` (Unix) or `bootstrap.ps1 -NonInteractive` (Windows).

## Inputs

Env (optional):
- `DOTFILES_REMOTE` — override clone URL (default `git@github.com:duthaho/dotfiles.git`).
- `DOTFILES_DIR` — override clone location (default `$HOME/.dotfiles`).

## Outputs

`~/.cache/devenv/20-dotfiles.done` on success.
