#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$dir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }

$ok = $true
$parts = New-Object System.Collections.Generic.List[string]

if (Test-Path (Join-Path $dir '.git')) {
    $branch = (git -C $dir branch --show-current 2>$null)
    $parts.Add("repo $dir on $branch")
    git -C $dir diff --quiet
    $a = $LASTEXITCODE
    git -C $dir diff --cached --quiet
    $b = $LASTEXITCODE
    if ($a -eq 0 -and $b -eq 0) { $parts.Add('clean') } else { $parts.Add('dirty') }
} else {
    $ok = $false; $parts.Add("$dir MISSING")
}

$status = if ($ok) { 'PASS' } else { 'FAIL' }
Write-Output ("{0,-4} {1}" -f $status, ($parts -join ', '))
if (-not $ok) { exit 1 }
