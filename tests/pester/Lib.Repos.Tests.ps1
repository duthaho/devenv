. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/repos.ps1 helpers' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . (Join-Path $env:DEVENV_ROOT 'lib/repos.ps1')
        $script:tmp = Join-Path $TestDrive 'repostests'
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null
    }

    It 'Get-DevenvReposDefaultPath strips .git and prefixes USERPROFILE/code' {
        $env:USERPROFILE = $script:tmp
        $p = Get-DevenvReposDefaultPath -Remote 'git@github.com:duthaho/duthaho.dev.git'
        $p | Should -Be (Join-Path $script:tmp 'code/duthaho.dev')
    }

    It 'Get-DevenvReposDefaultPath works for https remotes without .git suffix' {
        $env:USERPROFILE = $script:tmp
        $p = Get-DevenvReposDefaultPath -Remote 'https://github.com/duthaho/dotfiles'
        $p | Should -Be (Join-Path $script:tmp 'code/dotfiles')
    }

    It 'Get-DevenvReposEntries parses pipe-separated lines and skips comments' {
        $env:USERPROFILE = $script:tmp
        $f = Join-Path $script:tmp 'repos.txt'
@"
# header
git@github.com:a/one.git
https://github.com/b/two.git | C:/custom/path

git@github.com:c/three.git | ~/code/three | mise install && devbox install
"@ | Set-Content -Path $f -Encoding ASCII
        $rows = @(Get-DevenvReposEntries -Path $f)
        $rows.Count   | Should -Be 3
        $rows[0].Remote | Should -Be 'git@github.com:a/one.git'
        $rows[0].Path   | Should -Be (Join-Path $script:tmp 'code/one')
        $rows[0].Setup  | Should -BeNullOrEmpty
        $rows[1].Path   | Should -Be 'C:/custom/path'
        $rows[2].Setup  | Should -Be 'mise install && devbox install'
    }

    It 'Get-DevenvReposEntries returns empty when file missing' {
        $rows = @(Get-DevenvReposEntries -Path (Join-Path $script:tmp 'missing.txt'))
        $rows.Count | Should -Be 0
    }
}
