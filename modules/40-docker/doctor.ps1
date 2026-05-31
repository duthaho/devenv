#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ok = $true
$parts = @()

if (Get-Command docker -ErrorAction SilentlyContinue) {
    $ver = (& docker --version) -split ' '
    $parts += "docker $($ver[2].TrimEnd(','))"
} else { $ok = $false; $parts += 'docker MISSING' }

& docker info 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $parts += 'engine ok' } else { $ok = $false; $parts += 'engine UNREACHABLE' }

& docker compose version 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $parts += 'compose v2 ok' } else { $ok = $false; $parts += 'compose v2 MISSING' }

& docker network inspect devenv 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $parts += 'network devenv ok' } else { $ok = $false; $parts += 'network devenv MISSING' }

$status = if ($ok) { 'PASS' } else { 'FAIL' }
'{0,-4} {1}' -f $status, ($parts -join ', ')
if (-not $ok) { exit 1 }
