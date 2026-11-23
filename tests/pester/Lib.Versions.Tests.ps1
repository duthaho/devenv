. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/versions.ps1' {
    BeforeAll { . "$env:DEVENV_ROOT/lib/versions.ps1" }
    AfterEach { Remove-Item Env:DEVENV_TOOL_VERSIONS_FILE -ErrorAction SilentlyContinue }
    It 'validates the repository manifest and returns npm specifications' {
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvNpmSpec codex) | Should -Be '@openai/codex'
        (Get-DevenvNpmSpec wrangler) | Should -Be 'wrangler'
    }
    It 'uses a pinned test manifest for all installer inputs' {
        $file = Join-Path $TestDrive 'versions.txt'
        $body = Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt') -Raw
        $body = $body.Replace('codex.version=latest','codex.version=0.1.2').Replace('wrangler.version=latest','wrangler.version=3.4.5').Replace('awscli.version=latest','awscli.version=2.9.9')
        $sha = [string]::new('0', 64)
        $body = $body.TrimEnd() + "`n" + (@(
            "awscli.sha256.linux-x86_64=$sha",
            "awscli.sha256.linux-aarch64=$sha",
            "awscli.sha256.macos=$sha",
            "awscli.sha256.windows=$sha"
        ) -join "`n") + "`n"
        Set-Content -Path $file -Value $body -NoNewline
        $env:DEVENV_TOOL_VERSIONS_FILE = $file
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvNpmSpec codex) | Should -Be '@openai/codex@0.1.2'
        (Get-DevenvAwsCliUrl windows) | Should -Be 'https://awscli.amazonaws.com/AWSCLIV2-2.9.9.msi'
    }
    It 'parses CRLF manifest identically to Bash' {
        $file = Join-Path $TestDrive 'versions-crlf.txt'
        $content = Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt')
        [IO.File]::WriteAllLines($file, $content)
        $env:DEVENV_TOOL_VERSIONS_FILE = $file
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvNpmSpec codex) | Should -Be '@openai/codex'
    }
}
