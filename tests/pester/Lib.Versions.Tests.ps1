. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/versions.ps1' {
    BeforeAll { . "$env:DEVENV_ROOT/lib/versions.ps1" }
    AfterEach { Remove-Item Env:DEVENV_TOOL_VERSIONS_FILE -ErrorAction SilentlyContinue }
    It 'validates the repository manifest and returns npm specifications' {
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvNpmSpec codex) | Should -Be '@openai/codex'
        (Get-DevenvNpmSpec wrangler) | Should -Be 'wrangler'
    }
    It 'accepts a repo source with an X.Y minor' {
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvToolSetting kubectl version) | Should -Be '1.37'
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
        [IO.File]::WriteAllText($file, (($content -join "`r`n") + "`r`n"))
        $env:DEVENV_TOOL_VERSIONS_FILE = $file
        (Test-DevenvToolVersions) | Should -BeTrue
        (Get-DevenvNpmSpec codex) | Should -Be '@openai/codex'
    }

    It 'returns the same setting as Bash for every manifest key' {
        if (-not (Get-Command bash -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because 'bash not installed'; return }
        foreach ($line in Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt')) {
            if (-not $line -or $line.StartsWith('#')) { continue }
            $key = $line.Split('=', 2)[0]
            $parts = $key.Split('.', 2)
            $bashValue = (& bash -c 'source "$DEVENV_ROOT/lib/versions.sh"; devenv_tool_get "$1" "$2"' -- $parts[0] $parts[1]).Trim()
            (Get-DevenvToolSetting $parts[0] $parts[1]) | Should -Be $bashValue -Because $key
        }
    }

    $base = Get-Content (Join-Path $env:DEVENV_ROOT 'config/tool-versions.txt') -Raw
    $sha = [string]::new('0', 64)
    $validationCases = @(
        @{ Code = 'E_SYNTAX'; Body = "$base`nnot a manifest entry`n" },
        @{ Code = 'E_DUPLICATE'; Body = "$base`ncodex.version=latest`n" },
        @{ Code = 'E_MISSING'; Body = ($base -replace '(?m)^codex\.package=.*\r?\n?', '') },
        @{ Code = 'E_BAD_MODULE'; Body = $base.Replace('codex.module=65-ai-cli','codex.module=missing') },
        @{ Code = 'E_BAD_SOURCE'; Body = $base.Replace('codex.source=npm','codex.source=registry') },
        @{ Code = 'E_BAD_VERSION'; Body = $base.Replace('codex.version=latest','codex.version=v1.2.3') },
        @{ Code = 'E_MISSING_SHA'; Body = $base.Replace('awscli.version=latest','awscli.version=2.9.9') },
        @{ Code = 'E_BAD_SHA'; Body = $base.Replace('awscli.version=latest','awscli.version=2.9.9').TrimEnd() + "`nawscli.sha256.linux-x86_64=bad`nawscli.sha256.linux-aarch64=$sha`nawscli.sha256.macos=$sha`nawscli.sha256.windows=$sha`n" },
        @{ Code = 'E_SHA_ON_LATEST'; Body = $base.TrimEnd() + "`nawscli.sha256.windows=$sha`n" },
        @{ Code = 'E_SHA_ON_NPM'; Body = $base.TrimEnd() + "`ncodex.sha256.windows=$sha`n" },
        @{ Code = 'E_BAD_VERSION kubectl'; Body = $base.Replace('kubectl.version=1.37','kubectl.version=latest') },
        @{ Code = 'E_BAD_VERSION kubectl'; Body = $base.Replace('kubectl.version=1.37','kubectl.version=1.37.0') },
        @{ Code = 'E_SHA_ON_REPO kubectl'; Body = $base.TrimEnd() + "`nkubectl.sha256.windows=$sha`n" }
    )
    It 'rejects the <Code> fixture' -TestCases $validationCases {
        param($Code, $Body)
            $file = Join-Path $TestDrive "$Code.txt"
            [IO.File]::WriteAllText($file, $Body)
            $env:DEVENV_TOOL_VERSIONS_FILE = $file
            (Test-DevenvToolVersions) | Should -BeFalse -Because $Code
    }
}
