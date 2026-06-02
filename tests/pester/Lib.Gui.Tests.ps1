. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/gui.ps1 helpers' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . (Join-Path $env:DEVENV_ROOT 'lib/gui.ps1')
        $script:tmp = Join-Path $TestDrive 'guitests'
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null
    }

    It 'Test-DevenvGuiEnabled returns false by default' {
        Remove-Item Env:DEVENV_GUI_ENABLED -ErrorAction SilentlyContinue
        Test-DevenvGuiEnabled | Should -BeFalse
    }

    It 'Test-DevenvGuiEnabled returns true when DEVENV_GUI_ENABLED=1' {
        $env:DEVENV_GUI_ENABLED = '1'
        Test-DevenvGuiEnabled | Should -BeTrue
        Remove-Item Env:DEVENV_GUI_ENABLED -ErrorAction SilentlyContinue
    }

    It 'Test-DevenvGuiWingetJsonHasPackages returns false for empty Packages array' {
        $f = Join-Path $script:tmp 'empty.json'
        '{"Sources":[{"Packages":[]}]}' | Set-Content -Path $f -Encoding UTF8
        Test-DevenvGuiWingetJsonHasPackages -Path $f | Should -BeFalse
    }

    It 'Test-DevenvGuiWingetJsonHasPackages returns true when at least one package present' {
        $f = Join-Path $script:tmp 'has.json'
        '{"Sources":[{"Packages":[{"PackageIdentifier":"Mozilla.Firefox"}]}]}' | Set-Content -Path $f -Encoding UTF8
        Test-DevenvGuiWingetJsonHasPackages -Path $f | Should -BeTrue
    }
}
