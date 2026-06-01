#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"
. "$Root/lib/claude.ps1"

function Install-ClaudeCli {
    if ($env:DEVENV_SKIP_NPM_INSTALL -eq '1') { Write-DevenvInfo 'claude install skipped (DEVENV_SKIP_NPM_INSTALL=1)'; return }
    if (Get-Command claude -ErrorAction SilentlyContinue) { Write-DevenvInfo 'claude already installed'; return }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-DevenvWarn 'npm not on PATH; install Node via 30-toolchains, then re-run --only 60-claude.'
        return
    }
    Write-DevenvInfo 'npm install -g @anthropic-ai/claude-code'
    & npm install -g '@anthropic-ai/claude-code' *>$null
    Update-DevenvPath
}

function Invoke-McpServers {
    $file = Join-Path $Root 'config/claude/mcp-servers.json'
    if (Test-Path $file) { Install-DevenvClaudeMcpServers -Path $file }
}

function Invoke-PluginPacks {
    $file = if ($env:DEVENV_CLAUDE_PLUGIN_FILE) { $env:DEVENV_CLAUDE_PLUGIN_FILE } else { Join-Path $Root 'config/claude/plugin-packs.txt' }
    if (Test-Path $file) { Invoke-DevenvClaudeClonePluginPacks -Path $file }
}

Install-ClaudeCli
Invoke-McpServers
Invoke-PluginPacks
Write-DevenvInfo '60-claude: done'
