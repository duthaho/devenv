. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/00-base/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @"
@echo off
echo %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII
        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        Remove-Item Env:DEVENV_SKIP_SHELL_PRODUCTIVITY -ErrorAction SilentlyContinue
    }

    It 'installs gh and every productivity package by default' -Skip:(-not $IsWindows) {
        Remove-Item Env:DEVENV_SKIP_SHELL_PRODUCTIVITY -ErrorAction SilentlyContinue
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/00-base/run.ps1')
        $LASTEXITCODE | Should -Be 0
        $calls = Get-Content (Join-Path $TestDrive 'calls.log') -Raw
        $calls | Should -Match 'GitHub.cli'
        $calls | Should -Match 'BurntSushi.ripgrep.MSVC'
        $calls | Should -Match 'sharkdp.bat'
    }

    It 'does not install productivity packages when opted out' -Skip:(-not $IsWindows) {
        Clear-Content (Join-Path $TestDrive 'calls.log') -ErrorAction SilentlyContinue
        $env:DEVENV_SKIP_SHELL_PRODUCTIVITY = '1'
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/00-base/run.ps1')
        $LASTEXITCODE | Should -Be 0
        $calls = Get-Content (Join-Path $TestDrive 'calls.log') -Raw
        $calls | Should -Match 'GitHub.cli'
        $calls | Should -Not -Match 'junegunn.fzf|ripgrep|sharkdp.bat|zoxide'
    }
}
