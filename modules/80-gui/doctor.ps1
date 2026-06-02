#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/gui.ps1"

$parts = @()
if (Test-DevenvGuiEnabled) {
    $parts += 'opt-in: enabled'
} else {
    $parts += 'opt-in: disabled (set DEVENV_GUI_ENABLED=1)'
}

$wingetFile = Join-Path $Root 'config/gui/winget.json'
if (Test-DevenvGuiWingetJsonHasPackages -Path $wingetFile) {
    $obj = Get-Content $wingetFile -Raw | ConvertFrom-Json
    $n = 0
    foreach ($src in $obj.Sources) { if ($src.Packages) { $n += $src.Packages.Count } }
    $parts += "winget.json: $n packages"
} else {
    $parts += 'winget.json: empty/template'
}

"{0,-4} {1}" -f 'PASS', ($parts -join ', ') | Write-Output
