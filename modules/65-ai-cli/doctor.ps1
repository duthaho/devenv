#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot/../..").Path
. "$Root/lib/versions.ps1"

if (Get-Command codex -ErrorAction SilentlyContinue) {
    $version = (& codex --version | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $version) {
        $drift = Get-DevenvToolDrift codex $version
        if ($drift) { "WARN codex $version ($drift)" | Write-Output } else { "PASS codex $version" | Write-Output }
        exit 0
    }
}

if ($env:DEVENV_AI_CLI_ENABLED -ne '1') {
    'PASS codex not installed (opt-in disabled; set DEVENV_AI_CLI_ENABLED=1)' | Write-Output
} elseif (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    'WARN codex not installed (Node MISSING; install via 30-toolchains)' | Write-Output
} elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    'WARN codex not installed (npm MISSING; install Node via 30-toolchains)' | Write-Output
} else {
    'WARN codex not installed (opt-in enabled)' | Write-Output
}
exit 0
