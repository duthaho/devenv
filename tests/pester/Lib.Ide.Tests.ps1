. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/ide.ps1 helpers' -Tag 'Windows' {
    BeforeAll {
        . "$PSScriptRoot/TestHelper.ps1"
        . (Join-Path $env:DEVENV_ROOT 'lib/ide.ps1')
        $script:tmp = Join-Path $TestDrive 'idetests'
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null
    }

    It 'Get-DevenvIdeExtensions ignores comments and blanks' {
        $f = Join-Path $script:tmp 'exts.txt'
@"
# header
ms-python.python

eamodio.gitlens
"@ | Set-Content -Path $f -Encoding ASCII
        $list = @(Get-DevenvIdeExtensions -Path $f)
        $list.Count | Should -Be 2
        $list[0] | Should -Be 'ms-python.python'
        $list[1] | Should -Be 'eamodio.gitlens'
    }

    It 'Get-DevenvIdeExtensions returns empty when file missing' {
        $list = @(Get-DevenvIdeExtensions -Path (Join-Path $script:tmp 'missing.txt'))
        $list.Count | Should -Be 0
    }

    It 'Merge-DevenvIdeSettings merges overlay onto existing user settings' {
        $user = Join-Path $script:tmp 'user.json'
        $overlay = Join-Path $script:tmp 'overlay.json'
        '{"editor.fontSize":14,"editor.formatOnSave":false}' | Set-Content $user -Encoding UTF8
        '{"editor.formatOnSave":true,"files.trimTrailingWhitespace":true}' | Set-Content $overlay -Encoding UTF8
        Merge-DevenvIdeSettings -OverlayPath $overlay -UserPath $user
        $obj = Get-Content $user -Raw | ConvertFrom-Json
        $obj.'editor.fontSize'                | Should -Be 14
        $obj.'editor.formatOnSave'            | Should -BeTrue
        $obj.'files.trimTrailingWhitespace'   | Should -BeTrue
    }

    It 'Merge-DevenvIdeSettings creates user file when absent' {
        $user = Join-Path $script:tmp 'new.json'
        $overlay = Join-Path $script:tmp 'overlay2.json'
        '{"editor.formatOnSave":true}' | Set-Content $overlay -Encoding UTF8
        Merge-DevenvIdeSettings -OverlayPath $overlay -UserPath $user
        Test-Path $user | Should -BeTrue
        ((Get-Content $user -Raw) | ConvertFrom-Json).'editor.formatOnSave' | Should -BeTrue
    }
}
