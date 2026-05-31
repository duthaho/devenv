#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/docker.ps1"

$cmd = if ($args.Length -gt 0) { $args[0] } else { 'help' }
$rest = @()
if ($args.Length -gt 1) { $rest = @($args[1..($args.Length-1)]) }

function Show-Usage {
@'
Usage: devenv <command> [flags]

Commands:
  up [flags]               run the bootstrap orchestrator
  doctor                   run each module's doctor
  services up [profiles..] bring up baseline + named profiles (default if none)
  services down            stop all services
  services status          list running services
  services logs <svc>      tail a service's logs
  services init <svc> <p>  create per-project DB / bucket / index
  services nuke --yes      stop services AND wipe all volumes
  help                     this help

Not yet implemented: update, repos.
'@
}

function Invoke-Compose { param([string[]]$Argv) & docker compose @((Get-DevenvComposeArgs) + $Argv) }

$script:AllProfileFlags = @('--profile','default','--profile','aws','--profile','search','--profile','vectors','--profile','queues','--profile','analytics','--profile','observability','--profile','alt-db','--profile','auth')

function Invoke-ComposeAll { param([string[]]$Argv) Invoke-Compose -Argv ($script:AllProfileFlags + $Argv) }

function Invoke-Services {
    param([string[]]$Argv)
    if ($null -eq $Argv) { $Argv = @() }
    $sub = if ($Argv.Length -gt 0) { $Argv[0] } else { 'help' }
    $tail = @()
    if ($Argv.Length -gt 1) { $tail = @($Argv[1..($Argv.Length-1)]) }
    switch ($sub) {
        'up' {
            $profiles = if ($tail.Length -gt 0) { $tail } else { @('default') }
            $flags = @(); foreach ($p in $profiles) { $flags += @('--profile', $p) }
            Invoke-Compose ($flags + @('up','-d'))
        }
        'down'   { Invoke-ComposeAll @('down') }
        'status' { Invoke-ComposeAll @('ps') }
        'logs' {
            if ($tail.Length -lt 1) { Write-DevenvError 'services logs <service>'; exit 2 }
            Invoke-Compose @('logs','-f', $tail[0])
        }
        'init' {
            if ($tail.Length -lt 2) { Write-DevenvError 'services init <svc> <project>'; exit 2 }
            $svc = $tail[0]; $proj = $tail[1]
            $db = Get-DevenvDbForProject $proj
            switch ($svc) {
                'postgres'   { Invoke-Compose @('exec','-T','postgres','psql','-U','dev','-d','dev','-c',"CREATE DATABASE $db;") }
                'mysql'      { Invoke-Compose @('exec','-T','mysql','mysql','-u','root','-pdev','-e',"CREATE DATABASE IF NOT EXISTS $db;") }
                'minio'      { Invoke-Compose @('exec','-T','minio','sh','-c',"mc alias set local http://localhost:9000 dev devsecret >`$null && mc mb -p local/$proj-dev") }
                'opensearch' { Invoke-Compose @('exec','-T','opensearch','curl','-fsS','-X','PUT',"http://localhost:9200/$db") }
                default { Write-DevenvError "init: unsupported service '$svc' (supported: postgres, mysql, minio, opensearch)"; exit 2 }
            }
        }
        'nuke' {
            if (-not ($tail -contains '--yes')) { Write-DevenvError 'services nuke requires --yes'; exit 2 }
            Invoke-ComposeAll @('down','-v')
            Write-DevenvInfo 'All devenv volumes wiped.'
        }
        { @('help','-h','--help','') -contains $_ } { Show-Usage }
        default { Write-DevenvError "services: unknown subcommand '$sub'"; exit 2 }
    }
}

switch ($cmd) {
    'up'       { & pwsh -NoProfile -File (Join-Path $Root 'bootstrap.ps1') @rest; exit $LASTEXITCODE }
    'doctor'   {
        $rc = 0
        Get-ChildItem (Join-Path $Root 'modules') -Directory | Sort-Object Name | ForEach-Object {
            $doc = Join-Path $_.FullName 'doctor.ps1'
            if (Test-Path $doc) {
                $out = & pwsh -NoProfile -File $doc 2>&1
                if ($LASTEXITCODE -eq 0) { Write-Output "[OK]   $($_.Name) $out" }
                else                     { Write-Output "[FAIL] $($_.Name) $out"; $rc = 1 }
            } else { Write-Output "[--]   $($_.Name) (no doctor)" }
        }
        exit $rc
    }
    'services' { Invoke-Services -Argv $rest }
    { @('help','-h','--help') -contains $_ } { Show-Usage }
    { @('update','repos') -contains $_ } { Write-DevenvError "${cmd}: not implemented yet"; exit 2 }
    default { Write-DevenvError "Unknown command: ${cmd}"; Show-Usage; exit 2 }
}
