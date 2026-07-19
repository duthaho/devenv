#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/docker.ps1"
. "$Root/lib/doctor.ps1"

$cmd = if ($args.Length -gt 0) { $args[0] } else { 'help' }
$rest = @()
if ($args.Length -gt 1) { $rest = @($args[1..($args.Length-1)]) }

function Show-Usage {
@'
Usage: devenv <command> [flags]

Commands:
  up [flags]               run the bootstrap orchestrator
  doctor                   cross-platform environment health + each module's doctor
  services up [profiles..] bring up baseline + named profiles (default if none)
  services down            stop all services
  services status          list running services + readiness (nonzero exit if any not ready)
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

# Render a SERVICE/STATE/READY table from `docker compose ps --format json`.
# READY = Docker health when a healthcheck exists, else 'no-probe' when running,
# else the raw non-running state. Exits non-zero if any service is not ready.
function Invoke-ServicesStatus {
    $argv = (Get-DevenvComposeArgs) + $script:AllProfileFlags + @('ps','--format','json')
    $out = & docker compose @argv
    $rcDocker = $LASTEXITCODE
    if ($rcDocker -ne 0) {
        Write-DevenvError "docker compose ps failed (exit $rcDocker)"
        exit $rcDocker
    }
    $lines = @($out | Where-Object { $_ -and "$_".Trim() })
    if ($lines.Count -eq 0) {
        Write-DevenvInfo 'No services running.'
        exit 0
    }
    $useColor = -not [Console]::IsOutputRedirected
    Write-Output ('{0,-20} {1,-12} {2}' -f 'SERVICE','STATE','READY')
    $rc = 0
    foreach ($line in $lines) {
        $obj = $line | ConvertFrom-Json
        $state = [string]$obj.State
        $health = if ($obj.PSObject.Properties.Name -contains 'Health') { [string]$obj.Health } else { '' }
        $ready = if ($health) { $health } elseif ($state -eq 'running') { 'no-probe' } else { $state }
        if ($ready -ne 'healthy' -and $ready -ne 'no-probe') { $rc = 1 }
        $cell = $ready
        if ($useColor) {
            $code = switch ($ready) { 'healthy' {32} 'starting' {33} 'no-probe' {2} default {31} }
            $esc = [char]27
            $cell = "$esc[${code}m$ready$esc[0m"
        }
        Write-Output ('{0,-20} {1,-12} {2}' -f [string]$obj.Service, $state, $cell)
    }
    exit $rc
}

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
        'status' { Invoke-ServicesStatus }
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
        Write-Output 'Environment'
        foreach ($c in @(Get-DevenvDoctorEnv)) {
            Write-Output ("  {0,-5} {1,-11} {2}" -f $c.Status, $c.Name, $c.Detail)
            if ($c.Status -eq 'FAIL') { $rc = 1 }
        }
        Write-Output ''
        Write-Output 'Modules'
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
