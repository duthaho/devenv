#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"

function Install-Wrangler {
    if ($env:DEVENV_CLOUD_WRANGLER -ne '1') { return }
    if ($env:DEVENV_SKIP_NPM_INSTALL -eq '1' -or $env:DEVENV_SKIP_WRANGLER_INSTALL -eq '1') {
        Write-DevenvInfo 'wrangler install skipped (DEVENV_SKIP_NPM_INSTALL or DEVENV_SKIP_WRANGLER_INSTALL)'
        return
    }
    if (Get-Command wrangler -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "wrangler $((& wrangler --version | Select-Object -First 1)) already installed"
        return
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-DevenvWarn 'Node/npm not on PATH; install Node via 30-toolchains, then re-run -Force -Only 35-cloud-cli.'
        return
    }
    Write-DevenvInfo 'npm install -g wrangler'
    & npm install -g wrangler
    if ($LASTEXITCODE -ne 0) { throw "npm install -g wrangler failed (exit $LASTEXITCODE)" }
    Update-DevenvPath
    if (-not (Get-Command wrangler -ErrorAction SilentlyContinue)) { throw "Wrangler installation completed but 'wrangler --version' is unavailable." }
    & wrangler --version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Wrangler installation completed but 'wrangler --version' failed." }
    Write-DevenvInfo "wrangler $((& wrangler --version | Select-Object -First 1)) installed"
}

function Install-Cloudflared {
    if ($env:DEVENV_CLOUD_CLOUDFLARED -ne '1') { return }
    if ($env:DEVENV_SKIP_CLOUDFLARED_INSTALL -eq '1') {
        Write-DevenvInfo 'cloudflared install skipped (DEVENV_SKIP_CLOUDFLARED_INSTALL)'
        return
    }
    if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "cloudflared $((& cloudflared --version | Select-Object -First 1)) already installed"
        return
    }
    if ((Get-DevenvOs) -ne 'windows') { throw 'run.ps1 installs cloudflared only on Windows' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget is required to install cloudflared. Install 'App Installer' from the Microsoft Store." }
    Write-DevenvInfo 'winget install Cloudflare.cloudflared'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id Cloudflare.cloudflared
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget install Cloudflare.cloudflared failed (exit $LASTEXITCODE)" }
    Update-DevenvPath
    if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) { throw "cloudflared installation completed but 'cloudflared --version' is unavailable." }
    & cloudflared --version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "cloudflared installation completed but 'cloudflared --version' failed." }
    Write-DevenvInfo "cloudflared $((& cloudflared --version | Select-Object -First 1)) installed"
}

if ($env:DEVENV_CLOUD_WRANGLER -ne '1' -and $env:DEVENV_CLOUD_CLOUDFLARED -ne '1') {
    Write-DevenvInfo '35-cloud-cli skipped (select Cloudflare CLIs in the menu or set DEVENV_CLOUD_WRANGLER=1 / DEVENV_CLOUD_CLOUDFLARED=1)'
    exit 0
}

Install-Wrangler
Install-Cloudflared
Write-DevenvInfo '35-cloud-cli: done'
