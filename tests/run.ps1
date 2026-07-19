#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Resolve-Path "$Here/..")

if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Write-Error 'Pester 5+ not installed. Run: Install-Module Pester -Force -SkipPublisherCheck'
    exit 1
}

Import-Module Pester -MinimumVersion 5.0.0
$config = New-PesterConfiguration
$config.Run.Path        = './tests/pester'
$config.Run.Exit        = $true
$config.Output.Verbosity = 'Detailed'
# Windows-tagged suites depend on Windows-only stubs (e.g. .cmd shims); skip
# them off Windows instead of letting them fail.
if (-not $IsWindows) { $config.Filter.ExcludeTag = @('Windows') }
Invoke-Pester -Configuration $config
