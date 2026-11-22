. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/65-ai-cli/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @'
@echo off
exit /b 0
'@ | Set-Content -Path (Join-Path $script:stubs 'node.cmd') -Encoding ASCII
        @"
@echo off
echo npm %* >> "$TestDrive\calls.log"
echo @echo off > "$script:stubs\codex.cmd"
echo echo codex 1.2.3 >> "$script:stubs\codex.cmd"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'npm.cmd') -Encoding ASCII
        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
        $env:DEVENV_AI_CLI_ENABLED = '1'
        Remove-Item Env:DEVENV_SKIP_NPM_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_SKIP_CODEX_INSTALL -ErrorAction SilentlyContinue
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        Remove-Item Env:DEVENV_SKIP_NPM_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_SKIP_CODEX_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_AI_CLI_ENABLED -ErrorAction SilentlyContinue
    }

    It 'installs Codex through npm and verifies its version' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'install -g @openai/codex'
    }

    It 'doctor reports missing Node when Codex is absent' -Skip:(-not $IsWindows) {
        Remove-Item (Join-Path $script:stubs 'node.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'npm.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'codex.cmd') -ErrorAction SilentlyContinue
        $output = & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/doctor.ps1') 2>&1
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Node MISSING'
    }
}
