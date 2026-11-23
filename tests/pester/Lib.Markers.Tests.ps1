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
        Remove-Item Env:DEVENV_TOOL_VERSIONS_FILE -ErrorAction SilentlyContinue
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

    It 'changes only the owning module SHA when a manifest pin changes and matches Bash' {
        if (-not (Get-Command bash -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because 'bash not installed'; return }
        $manifest = Join-Path $env:DEVENV_TEST_SANDBOX 'versions.txt'
        $original = Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt') -Raw
        [IO.File]::WriteAllText($manifest, $original)
        $env:DEVENV_TOOL_VERSIONS_FILE = $manifest
        $ai = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli')
        $cloud = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli')
        $base = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/00-base')
        [IO.File]::WriteAllText($manifest, $original.Replace('codex.version=latest','codex.version=0.1.2'))
        $changedAi = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli')
        $changedCloud = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/35-cloud-cli')
        $changedBase = Get-DevenvModuleSha (Join-Path $env:DEVENV_ROOT 'modules/00-base')
        $changedAi | Should -Not -Be $ai
        $changedCloud | Should -Be $cloud
        $changedBase | Should -Be $base
        $bashSha = (& bash -c 'source "$DEVENV_ROOT/lib/markers.sh"; module_sha "$1"' -- (Join-Path $env:DEVENV_ROOT 'modules/65-ai-cli')).Trim()
        $changedAi | Should -Be $bashSha
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
