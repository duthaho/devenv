#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"

$os = Get-DevenvOs

function Install-WingetPackage {
    param([string[]]$Ids)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-DevenvError "winget is required on Windows. Install 'App Installer' from the Microsoft Store."
        throw 'winget missing'
    }
    foreach ($id in $Ids) {
        Write-DevenvInfo "winget install $id"
        & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id $id
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
            Write-DevenvWarn "winget exit $LASTEXITCODE for $id (treated as non-fatal)"
        }
    }
}

switch ($os) {
    'windows' {
        Install-WingetPackage -Ids @(
            'Git.Git',
            'GitHub.cli',
            'stedolan.jq',
            'charmbracelet.gum'
        )
        # Refresh PATH so freshly-installed tools are visible to this process
        # and (because we set $env:PATH) to any child processes spawned later.
        Update-DevenvPath
    }
    default {
        Write-DevenvInfo "Delegating 00-base to run.sh for OS=$os"
        & bash "$Here/run.sh"
        if ($LASTEXITCODE -ne 0) { throw "run.sh failed with exit $LASTEXITCODE" }
    }
}

Write-DevenvInfo "00-base: done"
