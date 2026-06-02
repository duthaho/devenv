#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/repos.ps1"

$ok = $true
$parts = @()

if (Get-Command git -ErrorAction SilentlyContinue) { $parts += 'git ok' } else { $ok = $false; $parts += 'git MISSING' }

$file = Join-Path $Root 'config/repos.txt'
$configured = 0
$present = 0
if (Test-Path $file) {
    foreach ($row in (Get-DevenvReposEntries -Path $file)) {
        $configured++
        if (Test-Path (Join-Path $row.Path '.git')) { $present++ }
    }
}
$parts += "repos $present/$configured present"

$status = if ($ok) { 'PASS' } else { 'FAIL' }
"{0,-4} {1}" -f $status, ($parts -join ', ') | Write-Output
if (-not $ok) { exit 1 }
