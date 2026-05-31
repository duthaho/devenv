#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/os.ps1"

$os = Get-DevenvOs
$ok = $true
$parts = @()

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $parts += "mise " + ((& mise --version) -split ' ')[0]
} else { $ok = $false; $parts += 'mise MISSING' }

if (Get-Command direnv -ErrorAction SilentlyContinue) {
    $parts += "direnv " + (& direnv --version)
} else { $ok = $false; $parts += 'direnv MISSING' }

$parts += 'devbox n/a (native Windows)'

$cfg = Join-Path $env:USERPROFILE '.config/mise/config.toml'
if (Test-Path $cfg) { $parts += 'mise-config ok' } else { $ok = $false; $parts += 'mise-config MISSING' }

$status = if ($ok) { 'PASS' } else { 'FAIL' }
'{0,-4} {1}' -f $status, ($parts -join ', ')
if (-not $ok) { exit 1 }
