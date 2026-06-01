# 60-claude

Installs Claude Code, registers MCP servers, and clones plugin packs.

## Config

- `config/claude/mcp-servers.json` — array of `{name, json}` entries handed to `claude mcp add-json`.
- `config/claude/plugin-packs.txt` — `owner/repo[#ref]` lines cloned into `~/.claude/plugins/cache/<owner>/<repo>`.

## Install

| OS         | Method                                        |
|------------|-----------------------------------------------|
| All        | `npm install -g @anthropic-ai/claude-code`    |

Requires Node from `30-toolchains` (mise's `node lts`). Skipped with a warning if `npm` is missing — re-run `devenv up --only 60-claude` after 30-toolchains finishes.

## Idempotency

- CLI install: skipped if `claude` is on PATH.
- MCP servers: `claude mcp add-json` is idempotent — re-registers cleanly.
- Plugin packs: existing checkouts get `git fetch`; missing checkouts get `git clone --depth 1`.
