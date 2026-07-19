. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/doctor.ps1 environment checks' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$env:DEVENV_ROOT/lib/doctor.ps1"
    }

    BeforeEach {
        $script:sandbox = New-DevenvTestSandbox
        $script:origPath = $env:PATH
        $script:origSock = $env:SSH_AUTH_SOCK
        $env:OP_MOCK = $null
    }

    AfterEach {
        $env:PATH = $script:origPath
        $env:SSH_AUTH_SOCK = $script:origSock
        $env:OP_MOCK = $null
        Remove-DevenvTestSandbox -Path $script:sandbox
    }

    It 'os check reports PASS' {
        (Get-DevenvDoctorOs).Status | Should -Be 'PASS'
        (Get-DevenvDoctorOs).Name   | Should -Be 'os'
    }

    It 'op check PASSes under OP_MOCK=1' {
        $env:OP_MOCK = '1'
        (Get-DevenvDoctorOp).Status | Should -Be 'PASS'
    }

    It 'op check FAILs when op is absent and OP_MOCK unset' {
        $env:PATH = $script:sandbox   # no op on this PATH
        $env:OP_MOCK = $null
        (Get-DevenvDoctorOp).Status | Should -Be 'FAIL'
    }

    It 'shims check PASSes when mise/shims is on PATH' {
        $env:PATH = (Join-Path $script:sandbox 'x/mise/shims')
        (Get-DevenvDoctorShims).Status | Should -Be 'PASS'
    }

    It 'shims check FAILs when mise is not resolvable' {
        $env:PATH = $script:sandbox   # no mise, no shims dir
        (Get-DevenvDoctorShims).Status | Should -Be 'FAIL'
    }

    It 'shell-hooks check PASSes when both hooks in the profile' {
        $prof = Join-Path $script:sandbox 'profile.ps1'
        Set-Content -Path $prof -Value "Invoke-Expression (& mise activate pwsh)`nInvoke-Expression (& direnv hook pwsh)"
        (Get-DevenvDoctorShellHooks -ProfilePath $prof).Status | Should -Be 'PASS'
    }

    It 'shell-hooks check WARNs when profile lacks hooks' {
        $prof = Join-Path $script:sandbox 'empty.ps1'
        Set-Content -Path $prof -Value '# nothing here'
        $r = Get-DevenvDoctorShellHooks -ProfilePath $prof
        $r.Status | Should -Be 'WARN'
        $r.Detail | Should -Match 'mise'
    }

    It 'ssh-agent check PASSes when SSH_AUTH_SOCK is set' {
        $env:SSH_AUTH_SOCK = (Join-Path $script:sandbox 'agent.sock')
        (Get-DevenvDoctorSshAgent).Status | Should -Be 'PASS'
    }

    It 'ssh-agent check WARNs when SSH_AUTH_SOCK is unset' {
        $env:SSH_AUTH_SOCK = $null
        (Get-DevenvDoctorSshAgent).Status | Should -Be 'WARN'
    }

    It 'interop check returns nothing off WSL' {
        # This host is not WSL.
        Get-DevenvDoctorInterop | Should -BeNullOrEmpty
    }

    It 'Get-DevenvDoctorEnv includes a FAIL object when shims cannot resolve' {
        $env:PATH = $script:sandbox
        $env:OP_MOCK = '1'
        $checks = @(Get-DevenvDoctorEnv)
        ($checks | Where-Object { $_.Status -eq 'FAIL' }).Count | Should -BeGreaterThan 0
    }

    It 'Get-DevenvDoctorEnv returns checks in the spec order' {
        $env:OP_MOCK = '1'
        $names = @(Get-DevenvDoctorEnv | ForEach-Object { $_.Name })
        $names[0]              | Should -Be 'os'
        $names[-1]             | Should -Be 'ssh-agent'
        ($names -join ',')     | Should -Match 'shell-hooks,shims,op'
    }
}
