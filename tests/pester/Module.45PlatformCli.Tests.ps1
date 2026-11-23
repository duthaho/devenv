. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/45-platform-cli PowerShell defaults' {
    It 'does not crash under StrictMode when optional environment variables are unset' {
        'DEVENV_PLATFORM_KUBECTL','DEVENV_PLATFORM_HELM','DEVENV_PLATFORM_OPENTOFU',
        'DEVENV_SKIP_PLATFORM_CLI_INSTALL','DEVENV_SKIP_KUBECTL_INSTALL','DEVENV_SKIP_HELM_INSTALL','DEVENV_SKIP_OPENTOFU_INSTALL' |
            ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
        $runOutput = @(& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1') 2>&1)
        $runExitCode = $LASTEXITCODE
        if ($runExitCode -ne 0) { throw "run.ps1 exited $runExitCode`: $($runOutput -join [Environment]::NewLine)" }
        $runOutput | Should -Match '45-platform-cli skipped'
        $doctorOutput = @(& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/doctor.ps1') 2>&1)
        $doctorExitCode = $LASTEXITCODE
        if ($doctorExitCode -ne 0) { throw "doctor.ps1 exited $doctorExitCode`: $($doctorOutput -join [Environment]::NewLine)" }
        $doctorOutput | Should -Match 'opt-in disabled'
    }
}

Describe 'modules/45-platform-cli/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
    }

    BeforeEach {
        @'
@echo off
echo winget %* >> "%TESTDRIVE%\calls.log"
echo @echo off > "%TESTDRIVE%\stubs\kubectl.cmd"
echo echo clientVersion: v1.34.0 >> "%TESTDRIVE%\stubs\kubectl.cmd"
echo @echo off > "%TESTDRIVE%\stubs\helm.cmd"
echo echo v3.17.0 >> "%TESTDRIVE%\stubs\helm.cmd"
echo @echo off > "%TESTDRIVE%\stubs\tofu.cmd"
echo echo OpenTofu v1.9.0 >> "%TESTDRIVE%\stubs\tofu.cmd"
exit /b 0
'@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII
        $env:DEVENV_PLATFORM_KUBECTL = '1'
        $env:DEVENV_PLATFORM_HELM = '0'
        $env:DEVENV_PLATFORM_OPENTOFU = '0'
        Remove-Item Env:DEVENV_SKIP_KUBECTL_INSTALL -ErrorAction SilentlyContinue
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        'DEVENV_PLATFORM_KUBECTL','DEVENV_PLATFORM_HELM','DEVENV_PLATFORM_OPENTOFU','DEVENV_SKIP_KUBECTL_INSTALL' |
            ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
    }

    It 'installs selected kubectl through winget' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'Kubernetes.kubectl'
    }

    It 'installs selected Helm through winget' -Skip:(-not $IsWindows) {
        $env:DEVENV_PLATFORM_KUBECTL = '0'
        $env:DEVENV_PLATFORM_HELM = '1'
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'Helm.Helm'
    }

    It 'installs selected OpenTofu through winget' -Skip:(-not $IsWindows) {
        $env:DEVENV_PLATFORM_KUBECTL = '0'
        $env:DEVENV_PLATFORM_OPENTOFU = '1'
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'OpenTofu.OpenTofu'
    }

    It 'skips a selected kubectl install when requested' -Skip:(-not $IsWindows) {
        $env:DEVENV_SKIP_KUBECTL_INSTALL = '1'
        $output = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'kubectl install skipped'
    }

    It 'skips the entire selected module when requested' -Skip:(-not $IsWindows) {
        $env:DEVENV_SKIP_PLATFORM_CLI_INSTALL = '1'
        $output = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/run.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'DEVENV_SKIP_PLATFORM_CLI_INSTALL'
        Remove-Item Env:DEVENV_SKIP_PLATFORM_CLI_INSTALL -ErrorAction SilentlyContinue
    }

    It 'doctor reports each disabled tool independently' -Skip:(-not $IsWindows) {
        $env:DEVENV_PLATFORM_KUBECTL = '0'
        $env:DEVENV_PLATFORM_HELM = '0'
        $env:DEVENV_PLATFORM_OPENTOFU = '0'
        $output = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/45-platform-cli/doctor.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'kubectl not installed \(opt-in disabled'
        $output | Should -Match 'Helm not installed \(opt-in disabled'
        $output | Should -Match 'OpenTofu not installed \(opt-in disabled'
    }
}
