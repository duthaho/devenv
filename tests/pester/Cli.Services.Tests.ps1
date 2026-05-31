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
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
    }

    BeforeEach {
        if (Test-Path $script:log) { Remove-Item $script:log -Force }
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
}
