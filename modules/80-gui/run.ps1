#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/gui.ps1"

if (-not (Test-DevenvGuiEnabled)) {
    Write-DevenvInfo '80-gui: opt-in, skipped (set DEVENV_GUI_ENABLED=1 to enable)'
    exit 0
}

if ($env:DEVENV_SKIP_GUI_INSTALL -eq '1') {
    Write-DevenvInfo '80-gui: skipped (DEVENV_SKIP_GUI_INSTALL=1)'
    exit 0
}

if ($env:DEVENV_GUI_WINGET_FILE) {
    $wingetFile = $env:DEVENV_GUI_WINGET_FILE
} else {
    $wingetFile = Join-Path $Root 'config/gui/winget.json'
}

Invoke-DevenvGuiWingetImport -Path $wingetFile

Write-DevenvInfo '80-gui: done'
