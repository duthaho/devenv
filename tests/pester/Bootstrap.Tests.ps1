. "$PSScriptRoot/TestHelper.ps1"

Describe 'bootstrap.ps1' {
    BeforeEach {
        . "$PSScriptRoot/TestHelper.ps1"
        $Script:Sandbox = New-DevenvTestSandbox
        $env:DEVENV_TEST_SANDBOX = $Script:Sandbox
        $Script:FakeRoot = Join-Path $Script:Sandbox 'fakerepo'
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'lib') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'modules/00-aaa') | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Script:FakeRoot 'modules/10-bbb') | Out-Null
        foreach ($f in 'log.ps1','os.ps1','markers.ps1','menu.ps1') {
            Copy-Item -Path (Join-Path $env:DEVENV_ROOT "lib/$f") -Destination (Join-Path $Script:FakeRoot "lib/$f")
        }
        Copy-Item -Path (Join-Path $env:DEVENV_ROOT 'bootstrap.ps1') -Destination (Join-Path $Script:FakeRoot 'bootstrap.ps1')

        $orderLog = Join-Path $Script:Sandbox 'order.log'
        Set-Content -Path $orderLog -Value '' -NoNewline
        $env:DEVENV_ORDER_LOG = $orderLog
        Set-Content -Path (Join-Path $Script:FakeRoot 'modules/00-aaa/run.ps1') -Value 'Add-Content -Path $env:DEVENV_ORDER_LOG -Value "ran 00-aaa"'
        Set-Content -Path (Join-Path $Script:FakeRoot 'modules/10-bbb/run.ps1') -Value 'Add-Content -Path $env:DEVENV_ORDER_LOG -Value "ran 10-bbb"'
        # bootstrap runs run.sh on Linux/macOS and run.ps1 on Windows — provide
        # both so this suite exercises the orchestrator on every platform.
        "#!/usr/bin/env bash`necho 'ran 00-aaa' >> `"`$DEVENV_ORDER_LOG`"" | Set-Content -Path (Join-Path $Script:FakeRoot 'modules/00-aaa/run.sh')
        "#!/usr/bin/env bash`necho 'ran 10-bbb' >> `"`$DEVENV_ORDER_LOG`"" | Set-Content -Path (Join-Path $Script:FakeRoot 'modules/10-bbb/run.sh')
    }

    AfterEach {
        if ($env:DEVENV_TEST_SANDBOX -and (Test-Path $env:DEVENV_TEST_SANDBOX)) {
            Remove-Item -Recurse -Force $env:DEVENV_TEST_SANDBOX
        }
        $env:DEVENV_ORDER_LOG = $null
        $env:DEVENV_TEST_SANDBOX = $null
    }

    It 'runs modules in sorted order' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1')
        $LASTEXITCODE | Should -Be 0
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        $lines = Get-Content $log
        $lines[0] | Should -Be 'ran 00-aaa'
        $lines[1] | Should -Be 'ran 10-bbb'
    }

    It 'second run is no-op when markers fresh' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') | Out-Null
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        Clear-Content $log
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1')
        $LASTEXITCODE | Should -Be 0
        (Get-Content $log -Raw) | Should -BeNullOrEmpty
    }

    It '-Force re-runs all modules' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') | Out-Null
        $log = Join-Path $env:DEVENV_TEST_SANDBOX 'order.log'
        Clear-Content $log
        & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') -Force
        $lines = Get-Content $log
        $lines.Count | Should -Be 2
    }

    It '-Reconfigure runs the menu and skips unchosen optional modules' {
        $fake = Join-Path $env:DEVENV_TEST_SANDBOX 'fakerepo'
        # optional modules the menu governs (both runners so any OS works)
        foreach ($m in '50-ide','80-gui') {
            New-Item -ItemType Directory -Force -Path (Join-Path $fake "modules/$m") | Out-Null
            Set-Content -Path (Join-Path $fake "modules/$m/run.ps1") -Value "Add-Content -Path `$env:DEVENV_ORDER_LOG -Value `"ran $m LANGS=`$env:DEVENV_LANGS`""
            "#!/usr/bin/env bash`necho `"ran $m LANGS=`$DEVENV_LANGS`" >> `"`$DEVENV_ORDER_LOG`"" | Set-Content -Path (Join-Path $fake "modules/$m/run.sh")
        }
        # a mise.config.toml so the language prompt has items
        New-Item -ItemType Directory -Force -Path (Join-Path $fake 'modules/30-toolchains') | Out-Null
        "[tools]`nnode = `"lts`"`ngo = `"1.24`"" | Set-Content -Path (Join-Path $fake 'modules/30-toolchains/mise.config.toml')

        # cross-platform gum stub: choose 50-ide (not 80-gui); langs node,go
        $stubs = Join-Path $env:DEVENV_TEST_SANDBOX 'stubs'
        New-Item -ItemType Directory -Force -Path $stubs | Out-Null
        "#!/usr/bin/env bash`nhdr=`"`$*`"`ncase `"`$hdr`" in *module*) echo 50-ide ;; *language*) printf '%s\n' node go ;; esac" | Set-Content -Path (Join-Path $stubs 'gum')
        @"
@echo off
echo %*| findstr /C:"module" >nul
if %errorlevel%==0 echo 50-ide
echo %*| findstr /C:"language" >nul
if %errorlevel%==0 (
echo node
echo go
)
"@ | Set-Content -Path (Join-Path $stubs 'gum.cmd') -Encoding ASCII
        if ($IsWindows) { } else { & chmod +x (Join-Path $stubs 'gum') }

        $sep = [IO.Path]::PathSeparator
        $origPath = $env:PATH
        $env:PATH = "$stubs$sep$origPath"
        try {
            & pwsh -NoProfile -File (Join-Path $fake 'bootstrap.ps1') -Reconfigure
            $LASTEXITCODE | Should -Be 0
        } finally { $env:PATH = $origPath }

        $out = Get-Content (Join-Path $env:DEVENV_TEST_SANDBOX 'order.log') -Raw
        $out | Should -Match 'ran 50-ide'
        $out | Should -Not -Match 'ran 80-gui'
        $out | Should -Match 'LANGS=node,go'
    }
}
