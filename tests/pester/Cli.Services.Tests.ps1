. "$PSScriptRoot/TestHelper.ps1"

Describe 'bin/devenv.ps1 services (mocked docker)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null

        # docker stub: log every argv into calls.log and succeed.
        @"
@echo off
echo docker %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII

        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
        $script:cli = Join-Path $env:DEVENV_ROOT 'bin/devenv.ps1'
        $script:log = Join-Path $TestDrive 'calls.log'

        # Rewrite the docker stub to emit JSONL for `ps` and exit with $ExitCode.
        function Set-StatusStub {
            param([int]$ExitCode, [string[]]$Lines)
            $emit = if ($Lines) { ($Lines | ForEach-Object { "echo $_" }) -join "`r`n" } else { '' }
            @"
@echo off
echo docker %* >> "$script:log"
echo %* | findstr /C:" ps " >nul
if errorlevel 1 goto end
$emit
:end
exit /b $ExitCode
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII
        }
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
    }

    BeforeEach {
        if (Test-Path $script:log) { Remove-Item $script:log -Force }
        # Restore the default logging stub so tests that overwrite docker.cmd
        # (status, init-retry) can't leak their stub into later tests.
        if ($IsWindows) {
            @"
@echo off
echo docker %* >> "$script:log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII
        }
    }

    It 'services help prints usage' -Skip:(-not $IsWindows) {
        $out = & pwsh -NoProfile -File $script:cli services help
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'services up \[profiles'
    }

    It 'services up calls docker compose with default profile' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services up | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $script:log -Raw) | Should -Match '--profile default'
        (Get-Content $script:log -Raw) | Should -Match 'up -d'
    }

    It 'services up {p1} {p2} uses both profiles' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services up search vectors | Out-Null
        $LASTEXITCODE | Should -Be 0
        $content = Get-Content $script:log -Raw
        $content | Should -Match '--profile search'
        $content | Should -Match '--profile vectors'
    }

    It 'services init postgres myapp issues CREATE DATABASE myapp_dev' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services init postgres myapp | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $script:log -Raw) | Should -Match 'CREATE DATABASE myapp_dev'
    }

    It 'services init unsupported service exits 2' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services init banana myapp 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }

    It 'services init retries a transient failure then succeeds' -Skip:(-not $IsWindows) {
        $counter = Join-Path $TestDrive 'counter.txt'
        Remove-Item $counter -ErrorAction SilentlyContinue
        @"
@echo off
echo %*| findstr /C:" exec " >nul
if errorlevel 1 exit /b 0
set n=0
if exist "$counter" set /p n=<"$counter"
set /a n+=1
>"$counter" echo %n%
if "%n%"=="1" ( echo ERROR 2002 1>&2 & exit /b 1 )
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII
        $env:DEVENV_INIT_RETRY_DELAY = '0'
        try { & pwsh -NoProfile -File $script:cli services init mysql myapp 2>&1 | Out-Null }
        finally { $env:DEVENV_INIT_RETRY_DELAY = $null }
        $LASTEXITCODE | Should -Be 0
        [int](Get-Content $counter) | Should -BeGreaterOrEqual 2
    }

    It 'services init gives up after exhausting retries' -Skip:(-not $IsWindows) {
        @"
@echo off
echo %*| findstr /C:" exec " >nul
if errorlevel 1 exit /b 0
echo ERROR 2002 1>&2
exit /b 1
"@ | Set-Content -Path (Join-Path $script:stubs 'docker.cmd') -Encoding ASCII
        $env:DEVENV_INIT_RETRY_DELAY = '0'; $env:DEVENV_INIT_RETRIES = '3'
        try { & pwsh -NoProfile -File $script:cli services init postgres myapp 2>&1 | Out-Null }
        finally { $env:DEVENV_INIT_RETRY_DELAY = $null; $env:DEVENV_INIT_RETRIES = $null }
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'services nuke without --yes exits 2' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services nuke 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
    }

    It 'services nuke --yes calls compose down -v' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services nuke --yes | Out-Null
        $LASTEXITCODE | Should -Be 0
        (Get-Content $script:log -Raw) | Should -Match 'down -v'
    }

    It 'services down passes every known profile to compose' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services down | Out-Null
        $LASTEXITCODE | Should -Be 0
        $content = Get-Content $script:log -Raw
        foreach ($p in @('default','aws','search','vectors','queues','analytics','observability','alt-db','auth')) {
            $content | Should -Match "--profile $p"
        }
    }

    It 'services nuke --yes passes every known profile to compose' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File $script:cli services nuke --yes | Out-Null
        $LASTEXITCODE | Should -Be 0
        $content = Get-Content $script:log -Raw
        foreach ($p in @('default','aws','search','vectors','queues','analytics','observability','alt-db','auth')) {
            $content | Should -Match "--profile $p"
        }
    }

    It 'services status renders READY table and exits 0 when all ready' -Skip:(-not $IsWindows) {
        Set-StatusStub -ExitCode 0 -Lines @(
            '{"Service":"postgres","State":"running","Health":"healthy"}',
            '{"Service":"mailpit","State":"running","Health":""}'
        )
        $out = & pwsh -NoProfile -File $script:cli services status 2>&1
        $LASTEXITCODE | Should -Be 0
        $text = ($out -join "`n")
        $text | Should -Match 'SERVICE'
        $text | Should -Match 'STATE'
        $text | Should -Match 'READY'
        $text | Should -Match 'postgres\s+running\s+healthy'
        $text | Should -Match 'mailpit\s+running\s+no-probe'
    }

    It 'services status exits non-zero when a service is not ready' -Skip:(-not $IsWindows) {
        Set-StatusStub -ExitCode 0 -Lines @(
            '{"Service":"postgres","State":"running","Health":"healthy"}',
            '{"Service":"minio","State":"running","Health":"starting"}'
        )
        $out = & pwsh -NoProfile -File $script:cli services status 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($out -join "`n") | Should -Match 'minio\s+running\s+starting'
    }

    It 'services status with no running services exits 0 with a notice' -Skip:(-not $IsWindows) {
        Set-StatusStub -ExitCode 0 -Lines @()
        $out = & pwsh -NoProfile -File $script:cli services status 2>&1
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'No services running'
    }

    It 'services status propagates a docker ps failure' -Skip:(-not $IsWindows) {
        Set-StatusStub -ExitCode 1 -Lines @()
        $out = & pwsh -NoProfile -File $script:cli services status 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($out -join "`n") | Should -Not -Match 'No services running'
    }
}
