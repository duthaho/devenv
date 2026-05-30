. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/os.ps1' {
    BeforeAll {
        . "$env:DEVENV_ROOT/lib/os.ps1"
    }

    It 'Get-DevenvOs returns a known value on the current host' {
        $os = Get-DevenvOs
        $os | Should -BeIn @('mac','linux','wsl','windows','unknown')
    }

    It 'Get-DevenvOs returns windows when running on Windows' -Skip:(-not $IsWindows) {
        Get-DevenvOs | Should -Be 'windows'
    }

    It 'Get-DevenvDistro returns empty string on non-Linux' -Skip:($IsLinux) {
        Get-DevenvDistro | Should -Be ''
    }
}
