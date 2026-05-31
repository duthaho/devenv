. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/40-docker/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null

        # Default docker stub: succeeds for info / network inspect / compose.
        # Per-test overrides may rewrite this.
        @"
@echo off
echo [docker] %* >> "$TestDrive\calls.log"
if /i "%1"=="--version" (
  echo Docker version 99.0.0, build deadbeef
  exit /b 0
)
if /i "%1"=="info" exit /b 0
if /i "%1"=="network" exit /b 0
if /i "%1"=="compose" exit /b 0
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII

        @"
@echo off
echo [winget] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII

        $script:origPath      = $env:PATH
        $script:origAutostart = $env:DEVENV_SERVICES_AUTOSTART
        $env:PATH = "$script:stubs;$env:PATH"
        $env:DEVENV_SERVICES_AUTOSTART = '0'
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        if ($null -ne $script:origAutostart) {
            $env:DEVENV_SERVICES_AUTOSTART = $script:origAutostart
        } else {
            Remove-Item Env:\DEVENV_SERVICES_AUTOSTART -ErrorAction SilentlyContinue
        }
    }

    It 'completes without error when docker is preinstalled' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/40-docker/run.ps1')
        $LASTEXITCODE | Should -Be 0
    }

    It 'skips network create when devenv network already exists' -Skip:(-not $IsWindows) {
        $log = Join-Path $TestDrive 'calls.log'
        if (Test-Path $log) { Remove-Item $log -Force }
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/40-docker/run.ps1') | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $log -Raw) | Should -Not -Match 'network create devenv'
    }

    It 'creates devenv network when network inspect fails' -Skip:(-not $IsWindows) {
        # Override docker stub: network inspect fails, network create succeeds.
        @"
@echo off
echo [docker] %* >> "$TestDrive\calls.log"
if /i "%1"=="info" exit /b 0
if /i "%1"=="network" if /i "%2"=="inspect" exit /b 1
if /i "%1"=="network" if /i "%2"=="create" exit /b 0
if /i "%1"=="compose" exit /b 0
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII

        $log = Join-Path $TestDrive 'calls.log'
        if (Test-Path $log) { Remove-Item $log -Force }
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/40-docker/run.ps1') | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $log -Raw) | Should -Match 'network create devenv'

        # Restore default docker stub for any subsequent tests.
        @"
@echo off
echo [docker] %* >> "$TestDrive\calls.log"
if /i "%1"=="--version" (
  echo Docker version 99.0.0, build deadbeef
  exit /b 0
)
if /i "%1"=="info" exit /b 0
if /i "%1"=="network" exit /b 0
if /i "%1"=="compose" exit /b 0
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII
    }

    It 'autostart skipped when DEVENV_SERVICES_AUTOSTART=0' -Skip:(-not $IsWindows) {
        $log = Join-Path $TestDrive 'calls.log'
        if (Test-Path $log) { Remove-Item $log -Force }
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/40-docker/run.ps1') | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $log -Raw) | Should -Not -Match 'compose .* up -d'
    }

    It 'doctor.ps1 reports PASS when stubs report success' -Skip:(-not $IsWindows) {
        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/40-docker/doctor.ps1')
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '^PASS'
    }
}
