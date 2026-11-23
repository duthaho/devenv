#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"

if ($env:DEVENV_SKIP_PLATFORM_CLI_INSTALL -eq '1') {
    Write-DevenvInfo '45-platform-cli skipped (DEVENV_SKIP_PLATFORM_CLI_INSTALL)'
    exit 0
}

function Install-PlatformTool {
    param(
        [Parameter(Mandatory)][string]$EnvironmentVariable,
        [Parameter(Mandatory)][string]$SkipVariable,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$WingetId,
        [Parameter(Mandatory)][string[]]$VersionArguments,
        [Parameter(Mandatory)][string]$DisplayName
    )
    if ((Get-Item "Env:$EnvironmentVariable" -ErrorAction SilentlyContinue).Value -ne '1') { return }
    if ((Get-Item "Env:$SkipVariable" -ErrorAction SilentlyContinue).Value -eq '1') {
        Write-DevenvInfo "$DisplayName install skipped ($SkipVariable)"
        return
    }
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-DevenvInfo "$DisplayName already installed"
        return
    }
    if ((Get-DevenvOs) -ne 'windows') { throw "run.ps1 installs $DisplayName only on Windows" }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget is required to install $DisplayName. Install 'App Installer' from the Microsoft Store." }
    Write-DevenvInfo "winget install $WingetId"
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id $WingetId
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget install $WingetId failed (exit $LASTEXITCODE)" }
    Update-DevenvPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) { throw "$DisplayName installation completed but '$Command' is unavailable." }
    & $Command @VersionArguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "$DisplayName installation completed but version check failed." }
    Write-DevenvInfo "$DisplayName installed"
}

if ($env:DEVENV_PLATFORM_KUBECTL -ne '1' -and $env:DEVENV_PLATFORM_HELM -ne '1' -and $env:DEVENV_PLATFORM_OPENTOFU -ne '1') {
    Write-DevenvInfo '45-platform-cli skipped (select platform CLIs in the menu or set DEVENV_PLATFORM_KUBECTL=1 / DEVENV_PLATFORM_HELM=1 / DEVENV_PLATFORM_OPENTOFU=1)'
    exit 0
}

Install-PlatformTool -EnvironmentVariable DEVENV_PLATFORM_KUBECTL -SkipVariable DEVENV_SKIP_KUBECTL_INSTALL -Command kubectl -WingetId Kubernetes.kubectl -VersionArguments @('version','--client') -DisplayName kubectl
Install-PlatformTool -EnvironmentVariable DEVENV_PLATFORM_HELM -SkipVariable DEVENV_SKIP_HELM_INSTALL -Command helm -WingetId Helm.Helm -VersionArguments @('version','--short') -DisplayName Helm
Install-PlatformTool -EnvironmentVariable DEVENV_PLATFORM_OPENTOFU -SkipVariable DEVENV_SKIP_OPENTOFU_INSTALL -Command tofu -WingetId OpenTofu.OpenTofu -VersionArguments @('version') -DisplayName OpenTofu
Write-DevenvInfo '45-platform-cli: done'
