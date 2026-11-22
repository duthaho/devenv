#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Get-Command codex -ErrorAction SilentlyContinue) {
    $version = (& codex --version | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $version) {
        "PASS codex $version" | Write-Output
        exit 0
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    'FAIL codex MISSING (Node MISSING; install via 30-toolchains)' | Write-Output
} elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    'FAIL codex MISSING (npm MISSING; install Node via 30-toolchains)' | Write-Output
} else {
    'FAIL codex MISSING' | Write-Output
}
exit 1
