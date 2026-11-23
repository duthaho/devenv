# 65-ai-cli

Opt-in installation of the official [OpenAI Codex CLI](https://developers.openai.com/codex/cli/).

## Install

The curated first-run menu leaves this module unchecked by default. Select it,
or explicitly opt in outside the menu with
`DEVENV_AI_CLI_ENABLED=1 devenv up --only 65-ai-cli` (PowerShell:
`$env:DEVENV_AI_CLI_ENABLED = '1'`). Without that selection, this module does
not install anything. On macOS, Linux, WSL2, and Windows it uses the official
npm package:

```text
npm install -g @openai/codex
```

It requires the Node toolchain installed by `30-toolchains` (mise's `node lts`).
If Node or npm is unavailable, the module warns and does not install anything.

## Version policy

Version policy lives in the shared `config/tool-versions.txt` manifest. It
currently uses npm's `latest` stable channel for `@openai/codex`; pinning is a
single manifest edit to an exact `X.Y.Z` version. The module checks `codex
--version` after a new installation and skips npm entirely when Codex is already
on `PATH`.

## Authentication

The bootstrap never starts a login flow or writes credentials. After
installation, authenticate interactively with your ChatGPT account using Codex,
or provide `OPENAI_API_KEY` for API-key authentication.

## CI and troubleshooting

- `DEVENV_SKIP_NPM_INSTALL=1` skips all npm global installs during smoke tests.
- `DEVENV_SKIP_CODEX_INSTALL=1` skips only this module's install step.
- `DEVENV_AI_CLI_ENABLED=1` explicitly enables this opt-in module outside the
  curated menu.
- Run `devenv doctor` to see whether Codex is installed, missing, or blocked by
  missing Node/npm.
