#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"
. "$Root/lib/ide.ps1"

function Get-VsCodeSettingsPath { Join-Path $env:APPDATA 'Code/User/settings.json' }
function Get-CursorSettingsPath { Join-Path $env:APPDATA 'Cursor/User/settings.json' }

function Install-VsCode {
    if ($env:DEVENV_SKIP_CODE_INSTALL -eq '1') { Write-DevenvInfo 'VS Code install skipped (DEVENV_SKIP_CODE_INSTALL=1)'; return }
    if (Get-Command code -ErrorAction SilentlyContinue) { Write-DevenvInfo 'VS Code already installed'; return }
    Write-DevenvInfo 'winget install Microsoft.VisualStudioCode'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id Microsoft.VisualStudioCode
    Update-DevenvPath
}

function Install-Cursor {
    if ($env:DEVENV_SKIP_CODE_INSTALL -eq '1') { Write-DevenvInfo 'Cursor install skipped (DEVENV_SKIP_CODE_INSTALL=1)'; return }
    if (Get-Command cursor -ErrorAction SilentlyContinue) { Write-DevenvInfo 'Cursor already installed'; return }
    Write-DevenvInfo 'winget install Anysphere.Cursor'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id Anysphere.Cursor
    Update-DevenvPath
}

function Invoke-VsCodeApply {
    $extFile = @()
    if ($env:DEVENV_VSCODE_EXT_FILE) { $extFile = $env:DEVENV_VSCODE_EXT_FILE } else { $extFile = Join-Path $Root 'config/ide/vscode-extensions.txt' }
    $overlay = Join-Path $Root 'config/ide/vscode-settings.json'
    Invoke-DevenvIdeInstallExtensions -Cli 'code' -Path $extFile
    if (Test-Path $overlay) { Merge-DevenvIdeSettings -OverlayPath $overlay -UserPath (Get-VsCodeSettingsPath) }
    Write-DevenvInfo 'VS Code config applied'
}

function Invoke-CursorApply {
    $extFile = @()
    if ($env:DEVENV_CURSOR_EXT_FILE) { $extFile = $env:DEVENV_CURSOR_EXT_FILE } else { $extFile = Join-Path $Root 'config/ide/cursor-extensions.txt' }
    $overlay = Join-Path $Root 'config/ide/cursor-settings.json'
    Invoke-DevenvIdeInstallExtensions -Cli 'cursor' -Path $extFile
    if (Test-Path $overlay) { Merge-DevenvIdeSettings -OverlayPath $overlay -UserPath (Get-CursorSettingsPath) }
    Write-DevenvInfo 'Cursor config applied'
}

Install-VsCode
Install-Cursor
Invoke-VsCodeApply
Invoke-CursorApply
Write-DevenvInfo '50-ide: done'
