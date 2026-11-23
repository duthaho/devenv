#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot/../..").Path
. "$Root/lib/versions.ps1"

function Test-Wrangler {
    if (Get-Command wrangler -ErrorAction SilentlyContinue) {
        $version = (& wrangler --version | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $version) { $drift = Get-DevenvToolDrift wrangler $version; if ($drift) { "WARN wrangler $version ($drift)" | Write-Output } else { "PASS wrangler $version" | Write-Output }; return }
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

function Test-AwsCli {
    if (Get-Command aws -ErrorAction SilentlyContinue) {
        $version = (& aws --version 2>&1 | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $version -like 'aws-cli/2.*') { $drift = Get-DevenvToolDrift awscli $version; if ($drift) { "WARN awscli $version ($drift)" | Write-Output } else { "PASS AWS CLI v2 $version" | Write-Output }; return }
        if ($LASTEXITCODE -eq 0 -and $version) { "WARN AWS CLI v1 installed ($version); v2 is required" | Write-Output; return }
    }
    if ($env:DEVENV_CLOUD_AWS -ne '1') { 'PASS AWS CLI not installed (opt-in disabled; set DEVENV_CLOUD_AWS=1)' | Write-Output }
    else { 'WARN AWS CLI v2 not installed (opt-in enabled)' | Write-Output }
}

Test-Wrangler
Test-Cloudflared
Test-AwsCli
