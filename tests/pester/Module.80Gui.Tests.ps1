. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/80-gui/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @"
@echo off
echo [winget] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII

        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        Remove-Item Env:DEVENV_GUI_ENABLED -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_SKIP_GUI_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_GUI_WINGET_FILE -ErrorAction SilentlyContinue
    }

    It 'opt-in skip when DEVENV_GUI_ENABLED unset' -Skip:(-not $IsWindows) {
        Remove-Item Env:DEVENV_GUI_ENABLED -ErrorAction SilentlyContinue
        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/80-gui/run.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '80-gui: opt-in, skipped'
    }

    It 'ci skip when DEVENV_SKIP_GUI_INSTALL=1' -Skip:(-not $IsWindows) {
        $env:DEVENV_GUI_ENABLED = '1'
        $env:DEVENV_SKIP_GUI_INSTALL = '1'
        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/80-gui/run.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '80-gui: skipped'
        Remove-Item Env:DEVENV_GUI_ENABLED
        Remove-Item Env:DEVENV_SKIP_GUI_INSTALL
    }

    It 'runs winget import when enabled and packages present' -Skip:(-not $IsWindows) {
        $f = Join-Path $TestDrive 'winget.json'
        '{"Sources":[{"Packages":[{"PackageIdentifier":"Mozilla.Firefox"}]}]}' | Set-Content -Path $f -Encoding UTF8
        $env:DEVENV_GUI_ENABLED = '1'
        $env:DEVENV_GUI_WINGET_FILE = $f
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/80-gui/run.ps1') | Out-Null
        (Get-Content (Join-Path $TestDrive 'calls.log') -Raw) | Should -Match 'import --import-file'
        Remove-Item Env:DEVENV_GUI_ENABLED
        Remove-Item Env:DEVENV_GUI_WINGET_FILE
    }
}
