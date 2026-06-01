. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/claude.ps1 helpers' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . (Join-Path $env:DEVENV_ROOT 'lib/claude.ps1')
        $script:tmp = Join-Path $TestDrive 'claudetests'
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null

        $script:stubs = Join-Path $TestDrive 'stubs'
        New-Item -ItemType Directory -Force -Path $script:stubs | Out-Null
        @"
@echo off
echo [claude] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'claude.cmd') -Encoding ASCII
        @"
@echo off
echo [git] %* >> "$TestDrive\calls.log"
exit /b 0
"@ | Set-Content -Path (Join-Path $script:stubs 'git.cmd') -Encoding ASCII
        $script:origPath = $env:PATH
        $env:PATH = "$script:stubs;$env:PATH"
    }
    AfterAll {
        if ($script:origPath) { $env:PATH = $script:origPath }
    }

    It 'Get-DevenvClaudePluginPacks ignores comments and blanks' {
        $f = Join-Path $script:tmp 'p.txt'
@"
# header
anthropics/claude-plugins-official

duthaho/gstack#main
"@ | Set-Content -Path $f -Encoding ASCII
        $list = @(Get-DevenvClaudePluginPacks -Path $f)
        $list.Count | Should -Be 2
        $list[0] | Should -Be 'anthropics/claude-plugins-official'
        $list[1] | Should -Be 'duthaho/gstack#main'
    }

    It 'Install-DevenvClaudeMcpServers calls claude mcp add-json per entry' {
        $f = Join-Path $script:tmp 'mcp.json'
        '[{"name":"filesystem","json":{"command":"npx"}}]' | Set-Content -Path $f -Encoding UTF8
        Install-DevenvClaudeMcpServers -Path $f
        (Get-Content (Join-Path $TestDrive 'calls.log') -Raw) | Should -Match 'mcp add-json filesystem'
    }
}
