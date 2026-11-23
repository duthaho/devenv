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

    It 'passes a pinned manifest spec to the real module' -Skip:(-not $IsWindows) {
        $manifest = Join-Path $TestDrive 'versions.txt'
        (Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt') -Raw).Replace('codex.version=latest','codex.version=0.1.2') | Set-Content $manifest -NoNewline
        $env:DEVENV_TOOL_VERSIONS_FILE = $manifest
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'install -g @openai/codex@0.1.2'
        (git -C $env:DEVENV_ROOT status --porcelain modules/) | Should -BeNullOrEmpty
        Remove-Item Env:DEVENV_TOOL_VERSIONS_FILE -ErrorAction SilentlyContinue
    }

    It 'warns about a pinned installed Codex drift without invoking npm' -Skip:(-not $IsWindows) {
        $manifest = Join-Path $TestDrive 'versions.txt'
        (Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt') -Raw).Replace('codex.version=latest','codex.version=0.1.2') | Set-Content $manifest -NoNewline
        @"
@echo off
echo codex 0.0.9
"@ | Set-Content -Path (Join-Path $script:stubs 'codex.cmd') -Encoding ASCII
        $env:DEVENV_TOOL_VERSIONS_FILE = $manifest
        $output = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/run.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'pinned 0.1.2, installed 0.0.9'
        Test-Path (Join-Path $TestDrive 'calls.log') | Should -BeFalse
        $doctor = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/doctor.ps1') 2>&1 | Out-String)
        $doctor | Should -Match 'WARN codex codex 0.0.9 \(pinned 0.1.2, installed 0.0.9\)'
        Remove-Item Env:DEVENV_TOOL_VERSIONS_FILE -ErrorAction SilentlyContinue
    }

    It 'doctor reports missing Node when Codex is absent' -Skip:(-not $IsWindows) {
        Remove-Item (Join-Path $script:stubs 'node.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'npm.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'codex.cmd') -ErrorAction SilentlyContinue
        $env:PATH = "$script:stubs;$env:SystemRoot\System32"
        $output = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli/doctor.ps1') 2>&1
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'Node MISSING'
    }
}
