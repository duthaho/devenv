#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/os.ps1"

$os = Get-DevenvOs
$ok = $true
$parts = New-Object System.Collections.Generic.List[string]

function Test-CmdAvailable { param($n)
    if (Get-Command $n -ErrorAction SilentlyContinue) { $parts.Add("$n ok") } else { $script:ok = $false; $parts.Add("$n MISSING") }
}
function Test-OptionalCmdAvailable { param($n)
    if (Get-Command $n -ErrorAction SilentlyContinue) { $parts.Add("$n ok") } else { $parts.Add("$n OPTIONAL-MISSING") }
}

if ($os -eq 'windows') { Test-CmdAvailable 'winget' }
Test-CmdAvailable 'git'
Test-CmdAvailable 'jq'
Test-CmdAvailable 'gum'
Test-CmdAvailable 'gh'
Test-OptionalCmdAvailable 'fzf'
Test-OptionalCmdAvailable 'rg'
Test-OptionalCmdAvailable 'bat'
Test-OptionalCmdAvailable 'zoxide'

$status = if ($ok) { 'PASS' } else { 'FAIL' }
Write-Output ("{0,-4} {1}" -f $status, ($parts -join ', '))
if (-not $ok) { exit 1 }
