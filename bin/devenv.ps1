#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/..").Path
. "$Root/lib/log.ps1"

$cmd = if ($args.Length -gt 0) { $args[0] } else { 'help' }
$rest = if ($args.Length -gt 1) { $args[1..($args.Length-1)] } else { @() }

function Show-Usage {
@'
Usage: devenv <command> [flags]

Commands (Phase 1):
  up [flags]      run the bootstrap orchestrator (forwards flags to bootstrap.ps1)
  doctor          run each module's doctor and report PASS/WARN/FAIL
  help            print this help

Phase 2+ (not yet implemented):
  update, services, repos
'@
}

switch ($cmd) {
    'up'     { & pwsh -NoProfile -File (Join-Path $Root 'bootstrap.ps1') @rest; exit $LASTEXITCODE }
    'doctor' {
        $rc = 0
        Get-ChildItem (Join-Path $Root 'modules') -Directory | Sort-Object Name | ForEach-Object {
            $doc = Join-Path $_.FullName 'doctor.ps1'
            if (Test-Path $doc) {
                $out = & pwsh -NoProfile -File $doc 2>&1
                if ($LASTEXITCODE -eq 0) { Write-Output "[OK]   $($_.Name) $out" }
                else                     { Write-Output "[FAIL] $($_.Name) $out"; $rc = 1 }
            } else {
                Write-Output "[--]   $($_.Name) (no doctor)"
            }
        }
        exit $rc
    }
    { @('help','-h','--help') -contains $_ } { Show-Usage }
    { @('update','services','repos') -contains $_ } { Write-DevenvError "${cmd}: not implemented in Phase 1"; exit 2 }
    default { Write-DevenvError "Unknown command: ${cmd}"; Show-Usage; exit 2 }
}
