#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"
. "$Root/lib/docker.ps1"

function Install-DockerDesktop {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-DevenvInfo 'docker CLI already present'
        return
    }
    Write-DevenvInfo 'winget install Docker.DockerDesktop'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id Docker.DockerDesktop
    Update-DevenvPath
    Write-DevenvWarn 'Open Docker Desktop once to start the engine, then re-run devenv up.'
}

Install-DockerDesktop

# Wait for the engine.
$reachable = $false
for ($i = 0; $i -lt 10; $i++) {
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $reachable = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $reachable) {
    Write-DevenvError 'Docker engine not reachable. Start Docker Desktop and re-run.'
    exit 1
}

& docker network inspect devenv 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-DevenvInfo 'Creating Docker network: devenv'
    & docker network create devenv
} else {
    Write-DevenvInfo "Docker network 'devenv' already exists"
}

& docker compose version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-DevenvError "'docker compose' (v2) not available."
    exit 1
}

$autostart = if ($env:DEVENV_SERVICES_AUTOSTART) { $env:DEVENV_SERVICES_AUTOSTART } else { '1' }
if ($autostart -eq '1') {
    Write-DevenvInfo 'Starting baseline services (profile: default)'
    $a = Get-DevenvComposeArgs
    & docker compose @a --profile default up -d
} else {
    Write-DevenvInfo "Autostart disabled (DEVENV_SERVICES_AUTOSTART=0)."
}

Write-DevenvInfo '40-docker: done'
