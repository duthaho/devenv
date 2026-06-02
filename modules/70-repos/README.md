# 70-repos

Clones the project repos listed in `config/repos.txt` and runs each repo's optional setup command.

## Config

`config/repos.txt` — one line per repo. Format:

```
remote [| path [| setup]]
```

- `remote` — git URL (ssh or https). Required.
- `path` — target directory. Defaults to `~/code/<basename of remote, .git stripped>`. `~/` expands to `$HOME`.
- `setup` — shell command run in the repo root after clone or fetch. Runs under `sh -c` on Unix and `pwsh -NoProfile -Command` on Windows.

Lines starting with `#` and blank lines are ignored.

## Idempotency

- Missing repo: `git clone --depth 1 <remote> <path>`.
- Existing repo: `git -C <path> fetch --tags --prune`.
- Setup runs every time (it should be idempotent — e.g. `mise install && devbox install`).

## Env

- `DEVENV_SKIP_REPO_CLONE=1` — skip the whole module (used by CI).
- `DEVENV_REPOS_FILE` — override the config file path (used by tests).
