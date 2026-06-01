. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/60-claude/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        foreach ($t in @('claude','npm','git')) {
            @"
@echo off
echo [$t] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs "$t.cmd") -Encoding ASCII
        }

        $script:fakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Force -Path $script:fakeHome | Out-Null

        $script:origPath = $env:PATH
        $script:origUP   = $env:USERPROFILE
        $env:PATH = "$script:stubs;$env:PATH"
        $env:USERPROFILE = $script:fakeHome
        $env:DEVENV_SKIP_NPM_INSTALL = '1'
        $env:DEVENV_CLAUDE_CACHE_DIR = (Join-Path $TestDrive 'cache')
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        if ($script:origUP)   { $env:USERPROFILE = $script:origUP }
        Remove-Item Env:DEVENV_SKIP_NPM_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_CLAUDE_CACHE_DIR -ErrorAction SilentlyContinue
    }

    It 'completes when claude already present' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/60-claude/run.ps1')
        $LASTEXITCODE | Should -Be 0
    }
}
