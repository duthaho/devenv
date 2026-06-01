. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/50-ide/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null

        @"
@echo off
echo [code] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'code.cmd') -Encoding ASCII
        @"
@echo off
echo [cursor] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'cursor.cmd') -Encoding ASCII
        @"
@echo off
echo [winget] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII

        $script:fakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Force -Path $script:fakeHome | Out-Null

        $script:origPath = $env:PATH
        $script:origAppData = $env:APPDATA
        $env:PATH = "$script:stubs;$env:PATH"
        $env:APPDATA = $script:fakeHome
        $env:DEVENV_SKIP_CODE_INSTALL = '1'
    }

    AfterAll {
        if ($script:origPath)    { $env:PATH    = $script:origPath }
        if ($script:origAppData) { $env:APPDATA = $script:origAppData }
        Remove-Item Env:DEVENV_SKIP_CODE_INSTALL -ErrorAction SilentlyContinue
    }

    It 'completes when code+cursor already present' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/50-ide/run.ps1')
        $LASTEXITCODE | Should -Be 0
    }

    It 'merges vscode-settings.json overlay into APPDATA user settings' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/50-ide/run.ps1') | Out-Null
        $settings = Join-Path $script:fakeHome 'Code\User\settings.json'
        Test-Path $settings | Should -BeTrue
        ((Get-Content $settings -Raw) | ConvertFrom-Json).'editor.formatOnSave' | Should -BeTrue
    }
}
