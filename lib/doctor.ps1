# Environment / host-wiring health checks for `devenv doctor`. Dot-source me.
#
# Each Get-DevenvDoctor* function returns a [pscustomobject]{Status;Name;Detail}
# (Status in PASS/WARN/FAIL) or $null to skip. Get-DevenvDoctorEnv returns the
# ordered array of non-null checks; the caller formats them and decides the exit
# result (FAIL fails, WARN does not).

. "$PSScriptRoot/os.ps1"
. "$PSScriptRoot/op.ps1"

function New-DevenvDoctorResult {
    param([string]$Status, [string]$Name, [string]$Detail)
    [pscustomobject]@{ Status = $Status; Name = $Name; Detail = $Detail }
}

function Get-DevenvDoctorOs {
    $os = Get-DevenvOs
    $distro = Get-DevenvDistro
    $detail = if ($distro) { "$os/$distro" } else { $os }
    New-DevenvDoctorResult 'PASS' 'os' $detail
}

function Get-DevenvDoctorInterop {
    if ((Get-DevenvOs) -ne 'wsl') { return $null }
    if ((Get-Command powershell.exe -ErrorAction SilentlyContinue) -or
        (Get-Command cmd.exe -ErrorAction SilentlyContinue)) {
        return New-DevenvDoctorResult 'PASS' 'interop' 'windows interop reachable'
    }
    New-DevenvDoctorResult 'WARN' 'interop' 'no windows interop (cmd.exe/powershell.exe not on PATH)'
}

function Get-DevenvDoctorShellHooks {
    param([string]$ProfilePath = $PROFILE.CurrentUserAllHosts)
    $miseOk = $false
    $direnvOk = $false
    if ($ProfilePath -and (Test-Path $ProfilePath)) {
        $content = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
        if ($content -match 'mise activate') { $miseOk = $true }
        if ($content -match 'direnv hook')   { $direnvOk = $true }
    }
    if ($miseOk -and $direnvOk) {
        return New-DevenvDoctorResult 'PASS' 'shell-hooks' 'mise+direnv wired'
    }
    $miss = @()
    if (-not $miseOk)   { $miss += 'mise' }
    if (-not $direnvOk) { $miss += 'direnv' }
    New-DevenvDoctorResult 'WARN' 'shell-hooks' ("missing hook: " + ($miss -join '+'))
}

function Get-DevenvDoctorShims {
    if ($env:PATH -like '*mise/shims*' -or $env:PATH -like '*mise\shims*') {
        return New-DevenvDoctorResult 'PASS' 'shims' 'mise shims on PATH'
    }
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        return New-DevenvDoctorResult 'WARN' 'shims' 'mise present but shims dir not on PATH (relying on activate hook)'
    }
    New-DevenvDoctorResult 'FAIL' 'shims' 'mise not resolvable (shims missing, no hook)'
}

function Get-DevenvDoctorOp {
    $os = Get-DevenvOs
    if ($env:OP_MOCK -ne '1' -and -not (Test-OpAvailable)) {
        return New-DevenvDoctorResult 'FAIL' 'op' 'op CLI MISSING'
    }
    if (Test-OpSignedIn) {
        return New-DevenvDoctorResult 'PASS' 'op' 'signed-in'
    }
    if ($os -in @('linux', 'wsl')) {
        return New-DevenvDoctorResult 'WARN' 'op' 'not-signed-in (run: op signin)'
    }
    New-DevenvDoctorResult 'FAIL' 'op' 'not-signed-in'
}

function Get-DevenvDoctorSshAgent {
    $os = Get-DevenvOs
    # Require the socket to actually exist, mirroring the bash `[ -S ]` check —
    # a stale SSH_AUTH_SOCK pointing at nothing must not report PASS.
    if ($env:SSH_AUTH_SOCK -and (Test-Path $env:SSH_AUTH_SOCK)) {
        return New-DevenvDoctorResult 'PASS' 'ssh-agent' 'agent socket present'
    }
    if ($os -eq 'windows' -and (Test-Path '\\.\pipe\openssh-ssh-agent')) {
        return New-DevenvDoctorResult 'PASS' 'ssh-agent' 'openssh agent pipe present'
    }
    if ($os -in @('mac', 'windows')) {
        return New-DevenvDoctorResult 'WARN' 'ssh-agent' 'no agent socket (expected 1Password agent)'
    }
    New-DevenvDoctorResult 'WARN' 'ssh-agent' 'no agent socket'
}

# Get-DevenvDoctorEnv — ordered array of non-null environment checks.
function Get-DevenvDoctorEnv {
    $checks = @(
        Get-DevenvDoctorOs
        Get-DevenvDoctorInterop
        Get-DevenvDoctorShellHooks
        Get-DevenvDoctorShims
        Get-DevenvDoctorOp
        Get-DevenvDoctorSshAgent
    )
    $checks | Where-Object { $null -ne $_ }
}
