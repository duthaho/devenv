. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/op.ps1' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$env:DEVENV_ROOT/lib/op.ps1"
    }

    BeforeEach {
        $sandbox = New-DevenvTestSandbox
        $env:DEVENV_TEST_SANDBOX = $sandbox
        $env:OP_MOCK = $null
    }

    AfterEach {
        Remove-DevenvTestSandbox -Path $env:DEVENV_TEST_SANDBOX
        $env:DEVENV_TEST_SANDBOX = $null
        $env:OP_MOCK = $null
    }

    It 'Test-OpSignedIn respects OP_MOCK=1' {
        $env:OP_MOCK = '1'
        Test-OpSignedIn | Should -Be $true
    }

    It 'Read-OpSecret returns mock-value when OP_MOCK=1' {
        $env:OP_MOCK = '1'
        Read-OpSecret 'op://vault/item/field' | Should -Be 'mock-value'
    }

    It 'Invoke-OpInject copies file when OP_MOCK=1' {
        $env:OP_MOCK = '1'
        $inp = Join-Path $env:DEVENV_TEST_SANDBOX 'in'
        $out = Join-Path $env:DEVENV_TEST_SANDBOX 'out'
        Set-Content -Path $inp -Value 'API_KEY={{ op://x/y/z }}'
        Invoke-OpInject -InputPath $inp -OutputPath $out
        Test-Path $out | Should -Be $true
        (Get-Content $out -Raw) | Should -Match 'op://x/y/z'
    }

    It 'Assert-OpSignedIn throws when not signed in' {
        $env:OP_MOCK = $null
        if (Test-OpSignedIn) {
            Set-ItResult -Skipped -Because 'host has op signed in; Assert-OpSignedIn would not throw'
            return
        }
        { Assert-OpSignedIn } | Should -Throw
    }
}
