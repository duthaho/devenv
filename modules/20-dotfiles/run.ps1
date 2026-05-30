#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"

$remote        = if ($env:DOTFILES_REMOTE) { $env:DOTFILES_REMOTE } else { 'git@github.com:duthaho/dotfiles.git' }
$httpsFallback = 'https://github.com/duthaho/dotfiles.git'
$dir           = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME '.dotfiles' }

if (Test-Path (Join-Path $dir '.git')) {
    Write-DevenvInfo "Updating $dir"
    git -C $dir fetch --quiet
    git -C $dir pull --ff-only
} else {
    Write-DevenvInfo "Cloning $remote -> $dir"
    & git clone $remote $dir 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-DevenvWarn 'SSH clone failed; falling back to HTTPS'
        & git clone $httpsFallback $dir
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
    }
}

$os = Get-DevenvOs
switch ($os) {
    'windows' {
        $boot = Join-Path $dir 'bootstrap.ps1'
        if (-not (Test-Path $boot)) { throw "$boot missing" }
        Write-DevenvInfo "Running $boot -NonInteractive"
        Push-Location $dir
        try { & pwsh -NoProfile -File $boot -NonInteractive } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "dotfiles bootstrap failed (exit $LASTEXITCODE)" }
    }
    default {
        $boot = Join-Path $dir 'bootstrap.sh'
        if (-not (Test-Path $boot)) { throw "$boot missing" }
        Write-DevenvInfo "Running $boot --non-interactive"
        Push-Location $dir
        try { & bash $boot --non-interactive } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { throw "dotfiles bootstrap failed (exit $LASTEXITCODE)" }
    }
}

Write-DevenvInfo "20-dotfiles: done"
