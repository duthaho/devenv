. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/docker.ps1' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$env:DEVENV_ROOT/lib/docker.ps1"
    }

    It 'Get-DevenvComposeMainPath ends with services/compose.yml' {
        (Get-DevenvComposeMainPath) | Should -Match 'services[\\/]compose\.yml$'
    }

    It 'Get-DevenvComposeLocalPath uses $HOME/.devenv/services/compose.local.yml' {
        $expected = Join-Path $HOME '.devenv/services/compose.local.yml'
        (Get-DevenvComposeLocalPath) | Should -Be $expected
    }

    It 'Get-DevenvComposeArgs is [-f main] when local does not exist' {
        $fakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Force -Path (Join-Path $fakeHome '.devenv/services') | Out-Null
        $orig = $HOME
        try {
            $env:HOME = $fakeHome
            Set-Variable -Name HOME -Value $fakeHome -Scope Global -Force
            $composeArgs = Get-DevenvComposeArgs
            ($composeArgs -join ' ') | Should -Match 'compose\.yml$'
            ($composeArgs -join ' ') | Should -Not -Match 'compose\.local\.yml'
        } finally {
            Set-Variable -Name HOME -Value $orig -Scope Global -Force
        }
    }

    It 'Get-DevenvDbForProject returns {project}_dev' {
        Get-DevenvDbForProject 'myapp' | Should -Be 'myapp_dev'
    }
}
