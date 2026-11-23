. "$PSScriptRoot/TestHelper.ps1"

Describe 'modules/35-cloud-cli/run.ps1 (mocked)' -Tag 'Windows' {
    BeforeAll {
        if (-not $IsWindows) { return }
        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @'
@echo off
exit /b 0
'@ | Set-Content -Path (Join-Path $script:stubs 'node.cmd') -Encoding ASCII
        @'
@echo off
exit /b 0
'@ | Set-Content -Path (Join-Path $script:stubs 'aws.cmd') -Encoding ASCII
        @"
@echo off
echo npm %* >> "$TestDrive\calls.log"
echo @echo off > "$script:stubs\wrangler.cmd"
echo echo wrangler 4.0.0 >> "$script:stubs\wrangler.cmd"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'npm.cmd') -Encoding ASCII
        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
        $env:DEVENV_CLOUD_WRANGLER = '1'
        $env:DEVENV_CLOUD_CLOUDFLARED = '0'
        $env:DEVENV_CLOUD_AWS = '0'
        Remove-Item Env:DEVENV_SKIP_NPM_INSTALL -ErrorAction SilentlyContinue
        Remove-Item Env:DEVENV_SKIP_WRANGLER_INSTALL -ErrorAction SilentlyContinue
    }

    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
        'DEVENV_CLOUD_WRANGLER','DEVENV_CLOUD_CLOUDFLARED','DEVENV_CLOUD_AWS','DEVENV_SKIP_NPM_INSTALL','DEVENV_SKIP_WRANGLER_INSTALL','DEVENV_SKIP_AWS_CLI_INSTALL' |
            ForEach-Object { Remove-Item "Env:$_" -ErrorAction SilentlyContinue }
    }

    It 'installs selected Wrangler through npm' -Skip:(-not $IsWindows) {
        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'install -g wrangler'
    }

    It 'installs selected cloudflared through winget' -Skip:(-not $IsWindows) {
        $env:DEVENV_CLOUD_WRANGLER = '0'
        $env:DEVENV_CLOUD_CLOUDFLARED = '1'
        @"
@echo off
echo winget %* >> "$TestDrive\calls.log"
echo @echo off > "$script:stubs\cloudflared.cmd"
echo echo cloudflared 2026.1.0 >> "$script:stubs\cloudflared.cmd"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'winget.cmd') -Encoding ASCII

        & pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli/run.ps1')
        $LASTEXITCODE | Should -Be 0
        Get-Content (Join-Path $TestDrive 'calls.log') -Raw | Should -Match 'install .*Cloudflare.cloudflared'
    }

    It 'doctor reports each disabled tool independently' -Skip:(-not $IsWindows) {
        $env:DEVENV_CLOUD_WRANGLER = '0'
        $env:DEVENV_CLOUD_CLOUDFLARED = '0'
        $env:DEVENV_CLOUD_AWS = '0'
        Remove-Item (Join-Path $script:stubs 'node.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'npm.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'wrangler.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'winget.cmd') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:stubs 'cloudflared.cmd') -ErrorAction SilentlyContinue
        $output = (& (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli/doctor.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'wrangler not installed \(opt-in disabled'
        $output | Should -Match 'cloudflared not installed \(opt-in disabled'
        $output | Should -Match 'AWS CLI not installed \(opt-in disabled'
    }

    It 'skips selected AWS CLI installation when requested' -Skip:(-not $IsWindows) {
        $env:DEVENV_CLOUD_WRANGLER = '0'
        $env:DEVENV_CLOUD_CLOUDFLARED = '0'
        $env:DEVENV_CLOUD_AWS = '1'
        $env:DEVENV_SKIP_AWS_CLI_INSTALL = '1'
        $output = (& pwsh -NoProfile -File (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli/run.ps1') 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'AWS CLI install skipped'
    }
}
