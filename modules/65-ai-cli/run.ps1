#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"
. "$Root/lib/versions.ps1"

function Install-CodexCli {
    if ($env:DEVENV_AI_CLI_ENABLED -ne '1') {
        Write-DevenvInfo '65-ai-cli skipped (set DEVENV_AI_CLI_ENABLED=1 or select it in the menu)'
        return
    }
    if ($env:DEVENV_SKIP_NPM_INSTALL -eq '1' -or $env:DEVENV_SKIP_CODEX_INSTALL -eq '1') {
        Write-DevenvInfo 'codex install skipped (DEVENV_SKIP_NPM_INSTALL or DEVENV_SKIP_CODEX_INSTALL)'
        return
    }
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "codex $((& codex --version | Select-Object -First 1)) already installed"
        return
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-DevenvWarn 'Node/npm not on PATH; install Node via 30-toolchains, then re-run -Only 65-ai-cli.'
        return
    }

    $spec = Get-DevenvNpmSpec codex
    Write-DevenvInfo "npm install -g $spec"
    & npm install -g $spec
    if ($LASTEXITCODE -ne 0) { throw "npm install -g $spec failed (exit $LASTEXITCODE)" }
    Update-DevenvPath
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw "Codex installation completed but 'codex --version' is unavailable. Restart the shell to refresh mise shims, then re-run -Only 65-ai-cli."
    }
    & codex --version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Codex installation completed but 'codex --version' failed." }
    Write-DevenvInfo "codex $((& codex --version | Select-Object -First 1)) installed"
}

Install-CodexCli
Write-DevenvInfo '65-ai-cli: done'
