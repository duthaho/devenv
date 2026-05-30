#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/op.ps1"

$ok = $true
$parts = New-Object System.Collections.Generic.List[string]

if (Get-Command op -ErrorAction SilentlyContinue) {
    $ver = (& op --version 2>$null)
    $parts.Add("op $ver")
} else {
    $ok = $false; $parts.Add('op MISSING')
}
if (Test-OpSignedIn) { $parts.Add('signed-in') } else { $ok = $false; $parts.Add('not-signed-in') }
$snippet = Join-Path $HOME '.ssh/config.d/10-1password.conf'
if (Test-Path $snippet) { $parts.Add('ssh-config ok') } else { $ok = $false; $parts.Add('ssh-config MISSING') }

$status = if ($ok) { 'PASS' } else { 'FAIL' }
Write-Output ("{0,-4} {1}" -f $status, ($parts -join ', '))
if (-not $ok) { exit 1 }
