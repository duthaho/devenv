. "$PSScriptRoot/TestHelper.ps1"

Describe 'lib/log.ps1' {
    It 'Write-DevenvInfo writes INFO line to stderr' {
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvInfo hello" 2>&1
        "$err" | Should -Match 'INFO'
        "$err" | Should -Match 'hello'
    }

    It 'Write-DevenvWarn writes WARN line' {
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvWarn careful" 2>&1
        "$err" | Should -Match 'WARN'
    }

    It 'Write-DevenvError writes ERROR line' {
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvError nope" 2>&1
        "$err" | Should -Match 'ERROR'
    }

    It 'Write-DevenvDebug is suppressed by default' {
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvDebug quiet" 2>&1
        $err | Should -BeNullOrEmpty
    }

    It 'Write-DevenvDebug fires when DEVENV_LOG_LEVEL=debug' {
        $err = pwsh -NoProfile -Command "`$env:DEVENV_LOG_LEVEL='debug'; . '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvDebug loud" 2>&1
        "$err" | Should -Match 'DEBUG'
    }

    It 'Write-DevenvInfo accepts an empty string (blank-line separators)' {
        # Regression: 10-1password's run.ps1 calls Write-DevenvInfo '' to print
        # a blank separator line. The Mandatory [string] parameter used to reject
        # empty strings with "Cannot bind argument to parameter 'Message'".
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvInfo ''" 2>&1
        $LASTEXITCODE | Should -Be 0
        "$err" | Should -Match 'INFO'
    }

    It 'Write-DevenvInfo accepts no arguments' {
        $err = pwsh -NoProfile -Command ". '$env:DEVENV_ROOT/lib/log.ps1'; Write-DevenvInfo" 2>&1
        $LASTEXITCODE | Should -Be 0
        "$err" | Should -Match 'INFO'
    }
}
