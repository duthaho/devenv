#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Wrangler {
    if (Get-Command wrangler -ErrorAction SilentlyContinue) {
        $version = (& wrangler --version | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $version) { "PASS wrangler $version" | Write-Output; return }
    }
    if ($env:DEVENV_CLOUD_WRANGLER -ne '1') { 'PASS wrangler not installed (opt-in disabled; set DEVENV_CLOUD_WRANGLER=1)' | Write-Output }
    elseif (-not (Get-Command node -ErrorAction SilentlyContinue)) { 'WARN wrangler not installed (Node MISSING; install via 30-toolchains)' | Write-Output }
    elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) { 'WARN wrangler not installed (npm MISSING; install Node via 30-toolchains)' | Write-Output }
    else { 'WARN wrangler not installed (opt-in enabled)' | Write-Output }
}

function Test-Cloudflared {
    if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
        $version = (& cloudflared --version | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $version) { "PASS cloudflared $version" | Write-Output; return }
    }
    if ($env:DEVENV_CLOUD_CLOUDFLARED -ne '1') { 'PASS cloudflared not installed (opt-in disabled; set DEVENV_CLOUD_CLOUDFLARED=1)' | Write-Output }
    else { 'WARN cloudflared not installed (opt-in enabled)' | Write-Output }
}

Test-Wrangler
Test-Cloudflared
