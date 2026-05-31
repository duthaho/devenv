#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"

$os = Get-DevenvOs

function Install-Mise {
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "mise already installed"
        return
    }
    Write-DevenvInfo 'winget install jdx.mise'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id jdx.mise
    Update-DevenvPath
}

function Install-Direnv {
    if (Get-Command direnv -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "direnv already installed"
        return
    }
    Write-DevenvInfo 'winget install direnv.direnv'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id direnv.direnv
    Update-DevenvPath
}

function Write-MiseConfig {
    $cfg = Join-Path $env:USERPROFILE '.config/mise/config.toml'
    if (Test-Path $cfg) {
        Write-DevenvInfo "mise config already at $cfg (left alone)"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $cfg -Parent) | Out-Null
    Copy-Item -Path (Join-Path $Here 'mise.config.toml') -Destination $cfg
    Write-DevenvInfo "Wrote $cfg"
}

switch ($os) {
    'windows' {
        Install-Mise
        Install-Direnv
        Write-DevenvWarn 'devbox skipped on native Windows (requires Nix; use WSL for devbox-managed envs)'
        Write-MiseConfig
    }
    default {
        Write-DevenvInfo "Delegating 30-toolchains to run.sh for OS=$os"
        & bash "$Here/run.sh"
        if ($LASTEXITCODE -ne 0) { throw "run.sh failed with exit $LASTEXITCODE" }
    }
}

Write-DevenvInfo '30-toolchains: done'
