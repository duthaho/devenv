. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/menu.ps1' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . "$env:DEVENV_ROOT/lib/log.ps1"
        . "$env:DEVENV_ROOT/lib/markers.ps1"
        . "$env:DEVENV_ROOT/lib/menu.ps1"

        $script:cfg = Join-Path $TestDrive 'mise.config.toml'
        @'
# comment
[tools]
node    = "lts"
python  = "3.13"
go      = "1.24"
rust    = "stable"

[settings]
experimental = true
'@ | Set-Content -Path $script:cfg

        $env:DEVENV_CACHE_DIR = Join-Path $TestDrive 'cache'
        New-Item -ItemType Directory -Force -Path $env:DEVENV_CACHE_DIR | Out-Null
    }

    BeforeEach {
        $env:DEVENV_LANGS = $null
        $env:DEVENV_GUI_ENABLED = $null
        $script:DevenvMenuSkip = $null
    }

    It 'Get-DevenvMenuLangs lists [tools] keys in order' {
        (Get-DevenvMenuLangs $script:cfg) | Should -Be @('node','python','go','rust')
    }

    It 'Test-DevenvMenuShouldShow is false under DEVENV_NON_INTERACTIVE' {
        $env:DEVENV_NON_INTERACTIVE = '1'
        try { Test-DevenvMenuShouldShow -Reconfigure | Should -BeFalse }
        finally { Remove-Item Env:DEVENV_NON_INTERACTIVE }
    }

    It 'Invoke-DevenvMenu maps a selection to skip + langs' {
        Mock Invoke-DevenvGumChoose {
            if ($Header -like '*module*') { return @('50-ide','70-repos') }
            if ($Header -like '*lang*')   { return @('node','go') }
            return @()
        }
        Invoke-DevenvMenu $script:cfg
        $script:DevenvMenuSkip | Should -Match '60-claude'
        $script:DevenvMenuSkip | Should -Match '80-gui'
        $script:DevenvMenuSkip | Should -Not -Match '50-ide'
        $env:DEVENV_LANGS | Should -Be 'node,go'
        [string]::IsNullOrEmpty($env:DEVENV_GUI_ENABLED) | Should -BeTrue
    }

    It 'Invoke-DevenvMenu enables gui when 80-gui chosen' {
        Mock Invoke-DevenvGumChoose {
            if ($Header -like '*module*') { return @('50-ide','80-gui') }
            if ($Header -like '*lang*')   { return @('node') }
            return @()
        }
        Invoke-DevenvMenu $script:cfg
        $env:DEVENV_GUI_ENABLED | Should -Be '1'
        $script:DevenvMenuSkip | Should -Not -Match '80-gui'
    }

    It 'Invoke-DevenvMenu leaves vars unset when gum cancels' {
        Mock Invoke-DevenvGumChoose { throw 'cancelled' }
        Invoke-DevenvMenu $script:cfg
        [string]::IsNullOrEmpty($env:DEVENV_LANGS) | Should -BeTrue
        [string]::IsNullOrEmpty($script:DevenvMenuSkip) | Should -BeTrue
    }
}
