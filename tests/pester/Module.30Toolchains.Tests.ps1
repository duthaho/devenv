. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/30-toolchains/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null

        # winget should never be called (Get-Command finds the mise/direnv stubs),
        # but stub it anyway so an accidental call doesn't escape the sandbox.
        @"
@echo off
echo [winget] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII

        @"
@echo off
echo [mise] %* >> "$TestDrive\calls.log"
echo mise 2099.1.0
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'mise.cmd') -Encoding ASCII

        @"
@echo off
echo [direnv] %* >> "$TestDrive\calls.log"
echo 2.32.0
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'direnv.cmd') -Encoding ASCII

        # Isolate USERPROFILE so the config write lands in TestDrive.
        $script:fakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Force -Path $script:fakeHome | Out-Null

        $script:origPath        = $env:PATH
        $script:origUserProfile = $env:USERPROFILE
        $env:PATH        = "$script:stubs;$env:PATH"
        $env:USERPROFILE = $script:fakeHome
    }

    AfterAll {
        if ($script:origPath)        { $env:PATH        = $script:origPath }
        if ($script:origUserProfile) { $env:USERPROFILE = $script:origUserProfile }
    }

    It 'completes without error when binaries are already present' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/30-toolchains/run.ps1')
        $LASTEXITCODE | Should -Be 0
    }

    It 'writes mise config.toml under USERPROFILE/.config/mise' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/30-toolchains/run.ps1') | Out-Null
        $cfg = Join-Path $script:fakeHome '.config/mise/config.toml'
        Test-Path $cfg | Should -BeTrue
        (Get-Content $cfg -Raw) | Should -Match 'node\s*=\s*"lts"'
    }

    It 'DEVENV_LANGS filters mise config to chosen tools' -Skip:(-not $IsWindows) {
        $cfg = Join-Path $script:fakeHome '.config/mise/config.toml'
        Remove-Item $cfg -Force -ErrorAction SilentlyContinue
        $env:DEVENV_LANGS_SET = '1'
        $env:DEVENV_LANGS = 'node,go'
        try {
            & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/30-toolchains/run.ps1') | Out-Null
        } finally { $env:DEVENV_LANGS = $null; $env:DEVENV_LANGS_SET = $null }
        $raw = Get-Content $cfg -Raw
        $raw | Should -Match 'node\s*='
        $raw | Should -Match 'go\s*='
        $raw | Should -Not -Match 'python\s*='
        $raw | Should -Not -Match 'rust\s*='
        $raw | Should -Match '\[settings\]'
    }

    It 'doctor.ps1 reports PASS when stubs report success' -Skip:(-not $IsWindows) {
        # Ensure the mise config exists for the doctor check.
        $cfgDir = Join-Path $script:fakeHome '.config/mise'
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        Set-Content -Path (Join-Path $cfgDir 'config.toml') -Value '# stub'

        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/30-toolchains/doctor.ps1')
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match '^PASS'
    }
}
