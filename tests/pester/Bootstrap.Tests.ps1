. "$PSScriptRoot/TestHelper.ps1"

Describe 'bootstrap.ps1' {
    BeforeEach {
        . "$PSScriptRoot/TestHelper.ps1"
        $Script:Sandbox = New-DevenvTestSandbox
        $env:DEVENV_TEST_SANDBOX = $Script:Sandbox
        $Script:FakeRoot = Join-Path $Script:Sandbox 'fakerepo'
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'lib') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'modules/00-aaa') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'modules/10-bbb') | Out-Null
        foreach ($f in 'log.ps1','os.ps1','markers.ps1') {
            Copy-Item -Path (Join-Path $env:DEVENV_ROOT "lib/$f") -Destination (Join-Path $Script:FakeRoot "lib/$f")
        }
        Copy-Item -Path (Join-Path $env:DEVENV_ROOT 'bootstrap.ps1') -Destination (Join-Path $Script:FakeRoot 'bootstrap.ps1')

        $orderLog = Join-Path $Script:Sandbox 'order.log'
        Set-Content -Path $orderLog -Value '' -NoNewline
        $env:DEVENV_ORDER_LOG = $orderLog
        Set-Content -Path (Join-Path $Script:FakeRoot 'modules/00-aaa/run.ps1') -Value 'Add-Content -Path $env:DEVENV_ORDER_LOG -Value "ran 00-aaa"'
        Set-Content -Path (Join-Path $Script:FakeRoot 'modules/10-bbb/run.ps1') -Value 'Add-Content -Path $env:DEVENV_ORDER_LOG -Value "ran 10-bbb"'
    }

    AfterEach {
        if ($env:DEVENV_TEST_SANDBOX -and (Test-Path $env:DEVENV_TEST_SANDBOX)) {
            Remove-Item -Recurse -Force $env:DEVENV_TEST_SANDBOX
        }
        $env:DEVENV_ORDER_LOG = $null
        $env:DEVENV_TEST_SANDBOX = $null
    }

    It 'runs modules in sorted order' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1')
        $LASTEXITCODE | Should -Be 0
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        $lines = Get-Content $log
        $lines[0] | Should -Be 'ran 00-aaa'
        $lines[1] | Should -Be 'ran 10-bbb'
    }

    It 'second run is no-op when markers fresh' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') | Out-Null
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        Clear-Content $log
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1')
        $LASTEXITCODE | Should -Be 0
        (Get-Content $log -Raw) | Should -BeNullOrEmpty
    }

    It '-Force re-runs all modules' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') | Out-Null
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        Clear-Content $log
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') -Force
        $lines = Get-Content $log
        $lines.Count | Should -Be 2
    }
}
