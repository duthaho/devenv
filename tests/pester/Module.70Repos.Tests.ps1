. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/70-repos/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @"
@echo off
echo [git] %* >> "$TestDrive\calls.log"
if /I "%1"=="clone" (
  for %%a in (%*) do set _last=%%a
  mkdir "%_last%\.git" 2>nul
)
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'git.cmd') -Encoding ASCII

        $script:fakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Force -Path (Join-Path $script:fakeHome 'code') | Out-Null

        $script:origPath = $env:PATH
        $script:origUP   = $env:USERPROFILE
        $env:PATH = "$script:stubs;$env:PATH"
        $env:USERPROFILE = $script:fakeHome
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        if ($script:origUP)   { $env:USERPROFILE = $script:origUP }
        Remove-Item Env:DEVENV_SKIP_REPO_CLONE -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_REPOS_FILE -ErrorAction SilentlyContinue
    }

    It 'skips when DEVENV_SKIP_REPO_CLONE=1' -Skip:(-not $IsWindows) {
        $env:DEVENV_SKIP_REPO_CLONE = '1'
        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/70-repos/run.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '70-repos: skipped'
        Remove-Item Env:DEVENV_SKIP_REPO_CLONE
    }

    It 'no-op when config file is empty' -Skip:(-not $IsWindows) {
        $empty = Join-Path $TestDrive 'empty.txt'
        New-Item -ItemType File -Force -Path $empty | Out-Null
        $env:DEVENV_REPOS_FILE = $empty
        $out = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/70-repos/run.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '70-repos: done'
        Remove-Item Env:DEVENV_REPOS_FILE
    }

    It 'clones repos listed in DEVENV_REPOS_FILE' -Skip:(-not $IsWindows) {
        $f = Join-Path $TestDrive 'repos.txt'
@"
https://github.com/x/alpha.git
"@ | Set-Content -Path $f -Encoding ASCII
        $env:DEVENV_REPOS_FILE = $f
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/70-repos/run.ps1') | Out-Null
        $log = Get-Content (Join-Path $TestDrive 'calls.log') -Raw
        $log | Should -Match 'clone --depth 1 https://github.com/x/alpha.git'
        Remove-Item Env:DEVENV_REPOS_FILE
    }
}
