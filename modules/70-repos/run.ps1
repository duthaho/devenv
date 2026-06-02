#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/repos.ps1"

if ($env:DEVENV_SKIP_REPO_CLONE -eq '1') {
    Write-DevenvInfo '70-repos: skipped (DEVENV_SKIP_REPO_CLONE=1)'
    exit 0
}

if ($env:DEVENV_REPOS_FILE) {
    $file = $env:DEVENV_REPOS_FILE
} else {
    $file = Join-Path $Root 'config/repos.txt'
}

if (-not (Test-Path $file)) {
    Write-DevenvInfo "70-repos: no $file; nothing to do"
    Write-DevenvInfo '70-repos: done'
    exit 0
}

$count = 0
foreach ($row in (Get-DevenvReposEntries -Path $file)) {
    Write-DevenvInfo "sync $($row.Remote) -> $($row.Path)"
    Invoke-DevenvReposSyncOne -Remote $row.Remote -Path $row.Path -Setup $row.Setup
    $count++
}

Write-DevenvInfo "70-repos: synced $count repo(s)"
Write-DevenvInfo '70-repos: done'
