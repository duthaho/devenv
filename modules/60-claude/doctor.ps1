#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ok = $true
$parts = @()

if (Get-Command claude -ErrorAction SilentlyContinue) { $parts += 'claude ok' } else { $ok = $false; $parts += 'claude MISSING' }

$cache = Join-Path $env:USERPROFILE '.claude/plugins/cache'
$n = 0
if (Test-Path $cache) {
    $n = @(Get-ChildItem $cache -Recurse -Directory -Filter '.git' -ErrorAction SilentlyContinue).Count
}
$parts += "plugin-packs $n"

$status = if ($ok) { 'PASS' } else { 'FAIL' }
"{0,-4} {1}" -f $status, ($parts -join ', ') | Write-Output
if (-not $ok) { exit 1 }
