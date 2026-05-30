#!/usr/bin/env pwsh
param(
    [string]$Only = '',
    [string]$Skip = '',
    [string]$From = '',
    [switch]$Force,
    [switch]$NonInteractive,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$Here/lib/log.ps1"
. "$Here/lib/os.ps1"
. "$Here/lib/markers.ps1"

function Show-Usage {
@'
Usage: bootstrap.ps1 [flags]

Flags:
  -Only "m1,m2"          only run these modules
  -Skip "m1,m2"          skip these modules
  -From "name"           run starting from this module
  -Force                 ignore .done markers
  -NonInteractive        set $env:DEVENV_NON_INTERACTIVE = 1
  -Help                  print this help
'@
}

if ($Help) { Show-Usage; return }
if ($NonInteractive) { $env:DEVENV_NON_INTERACTIVE = '1' }

function Test-CsvContains { param($Needle, $Csv) return ($Csv -split ',' | Where-Object { $_.Trim() -eq $Needle }).Count -gt 0 }

$os = Get-DevenvOs
Write-DevenvInfo "devenv bootstrap on $os"

$modulesDir = Join-Path $Here 'modules'
if (-not (Test-Path $modulesDir)) { Write-DevenvError "modules/ not found at $modulesDir"; exit 1 }

$mods = Get-ChildItem $modulesDir -Directory | Sort-Object Name
$reachedFrom = -not $From

$failed = $false
foreach ($mod in $mods) {
    $name = $mod.Name

    if ($From -and -not $reachedFrom) {
        if ($name -eq $From) { $reachedFrom = $true } else { Write-DevenvDebug "skip (before -From): $name"; continue }
    }
    if ($Only -and -not (Test-CsvContains $name $Only)) { Write-DevenvDebug "skip (not in -Only): $name"; continue }
    if ($Skip -and       (Test-CsvContains $name $Skip)) { Write-DevenvInfo "skip (in -Skip): $name"; continue }

    $runner = if ($os -eq 'windows') { 'run.ps1' } else { 'run.sh' }
    $runnerPath = Join-Path $mod.FullName $runner
    if (-not (Test-Path $runnerPath)) { Write-DevenvWarn "${name}: no $runner, skipping"; continue }

    $sha = Get-DevenvModuleSha -ModuleDir $mod.FullName
    if (-not $Force -and $sha -and (Test-DevenvDone -Module $name -Sha $sha)) {
        Write-DevenvInfo "${name}: up-to-date (cached)"; continue
    }

    Write-DevenvInfo "==> $name"
    try {
        if ($runner -eq 'run.ps1') {
            & pwsh -NoProfile -File $runnerPath
        } else {
            & bash $runnerPath
        }
        if ($LASTEXITCODE -ne 0) { throw "$name exit $LASTEXITCODE" }
    } catch {
        Write-DevenvError "$name failed: $_"
        $failed = $true
        break
    }

    if ($sha) { Set-DevenvDone -Module $name -Sha $sha }
}

if ($failed) {
    Write-DevenvError 'bootstrap aborted. Inspect ~/.cache/devenv/*.log, then re-run.'
    exit 1
}
Write-DevenvInfo 'bootstrap complete'
