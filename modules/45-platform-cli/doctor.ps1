#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DevenvEnvironmentValue {
    param([Parameter(Mandatory)][string]$Name)
    return [Environment]::GetEnvironmentVariable($Name, 'Process')
}

function Test-PlatformTool {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$EnvironmentVariable,
        [Parameter(Mandatory)][string[]]$VersionArguments
    )
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        $version = (& $Command @VersionArguments 2>$null | Select-Object -First 1)
        if ($version) { "PASS $DisplayName $version" | Write-Output; return }
    }
    if ((Get-DevenvEnvironmentValue $EnvironmentVariable) -ne '1') {
        "PASS $DisplayName not installed (opt-in disabled; set $EnvironmentVariable=1)" | Write-Output
    } else {
        "WARN $DisplayName not installed (opt-in enabled)" | Write-Output
    }
}

Test-PlatformTool -Command kubectl -DisplayName kubectl -EnvironmentVariable DEVENV_PLATFORM_KUBECTL -VersionArguments @('version','--client')
Test-PlatformTool -Command helm -DisplayName Helm -EnvironmentVariable DEVENV_PLATFORM_HELM -VersionArguments @('version','--short')
Test-PlatformTool -Command tofu -DisplayName OpenTofu -EnvironmentVariable DEVENV_PLATFORM_OPENTOFU -VersionArguments @('version')
