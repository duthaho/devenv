#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ok = $true
$parts = @()

if (Get-Command code -ErrorAction SilentlyContinue) { $parts += 'code ok' } else { $parts += 'code MISSING' }
if (Get-Command cursor -ErrorAction SilentlyContinue) { $parts += 'cursor ok' } else { $parts += 'cursor MISSING' }

$vscode  = Join-Path $env:APPDATA 'Code/User/settings.json'
$cursor  = Join-Path $env:APPDATA 'Cursor/User/settings.json'
if (Test-Path $vscode)  { $parts += 'vscode-settings ok' }  else { $parts += 'vscode-settings MISSING' }
if (Test-Path $cursor)  { $parts += 'cursor-settings ok' }  else { $parts += 'cursor-settings MISSING' }

$status = if ($ok) { 'PASS' } else { 'FAIL' }
"{0,-4} {1}" -f $status, ($parts -join ', ') | Write-Output
if (-not $ok) { exit 1 }
