. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/markers.ps1' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$env:DEVENV_ROOT/lib/markers.ps1"
    }

    BeforeEach {
        $sandbox = New-DevenvTestSandbox
        $env:DEVENV_TEST_SANDBOX = $sandbox
    }

    AfterEach {
        Remove-DevenvTestSandbox -Path $env:DEVENV_TEST_SANDBOX
        $env:DEVENV_CACHE_DIR = $null
        $env:DEVENV_TEST_SANDBOX = $null
    }

    It 'Get-DevenvMarkerPath uses DEVENV_CACHE_DIR' {
        $p = Get-DevenvMarkerPath -Module '00-base'
        $p | Should -Be (Join-Path $env:DEVENV_CACHE_DIR '00-base.done')
    }

    It 'Get-DevenvModuleSha is stable across calls' {
        $mod = Join-Path $env:DEVENV_TEST_SANDBOX 'modfake'
        New-Item -ItemType Directory -Path $mod | Out-Null
        Set-Content -Path (Join-Path $mod 'run.sh') -Value 'run'
        Set-Content -Path (Join-Path $mod 'README.md') -Value 'r'
        $a = Get-DevenvModuleSha -ModuleDir $mod
        $b = Get-DevenvModuleSha -ModuleDir $mod
        $a | Should -Not -BeNullOrEmpty
        $a | Should -Be $b
    }

    It 'Get-DevenvModuleSha changes when run.sh changes' {
        $mod = Join-Path $env:DEVENV_TEST_SANDBOX 'modfake'
        New-Item -ItemType Directory -Path $mod | Out-Null
        Set-Content -Path (Join-Path $mod 'run.sh') -Value 'v1'
        $a = Get-DevenvModuleSha -ModuleDir $mod
        Set-Content -Path (Join-Path $mod 'run.sh') -Value 'v2'
        $b = Get-DevenvModuleSha -ModuleDir $mod
        $a | Should -Not -Be $b
    }

    It 'Test-DevenvDone returns false when marker missing' {
        Test-DevenvDone -Module '00-base' -Sha 'abc' | Should -Be $false
    }

    It 'Set-DevenvDone + Test-DevenvDone round-trip' {
        Set-DevenvDone -Module '00-base' -Sha 'abc123'
        Test-DevenvDone -Module '00-base' -Sha 'abc123' | Should -Be $true
    }

    It 'Test-DevenvDone false on sha mismatch' {
        Set-DevenvDone -Module '00-base' -Sha 'abc123'
        Test-DevenvDone -Module '00-base' -Sha 'different' | Should -Be $false
    }

    It 'Clear-DevenvDone removes marker' {
        Set-DevenvDone -Module '00-base' -Sha 'abc'
        Clear-DevenvDone -Module '00-base'
        Test-DevenvDone -Module '00-base' -Sha 'abc' | Should -Be $false
    }
}
