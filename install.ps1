#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repo   = if ($env:DEVENV_REPO)   { $env:DEVENV_REPO }   else { 'https://github.com/duthaho/devenv.git' }
$Branch = if ($env:DEVENV_BRANCH) { $env:DEVENV_BRANCH } else { 'main' }
$Dest   = if ($env:DEVENV_DIR)    { $env:DEVENV_DIR }    else { Join-Path $env:LOCALAPPDATA 'devenv' }

function Note { param($Msg) Write-Host "[devenv] $Msg" -ForegroundColor Cyan }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Note 'git not found. Installing via winget...'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not available. Install "App Installer" from the Microsoft Store, then re-run.'
    }
    & winget install --silent --accept-source-agreements --accept-package-agreements --id Git.Git
    $env:PATH = "$env:PATH;$env:ProgramFiles\Git\cmd"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git install failed; open a new terminal and try again.'
    }
}

if (Test-Path (Join-Path $Dest '.git')) {
    Note "Updating existing clone at $Dest"
    git -C $Dest fetch --quiet
    git -C $Dest checkout --quiet $Branch
    git -C $Dest pull --ff-only
} else {
    Note "Cloning $Repo -> $Dest"
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
    git clone --branch $Branch $Repo $Dest
}

Note "Executing $Dest\bootstrap.ps1"
& pwsh -NoProfile -File (Join-Path $Dest 'bootstrap.ps1') @args
exit $LASTEXITCODE
