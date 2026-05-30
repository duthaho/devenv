# 1Password CLI wrappers. Dot-source me. Honors $env:OP_MOCK = '1'.

. "$PSScriptRoot/log.ps1"

function Test-OpAvailable {
    return [bool](Get-Command op -ErrorAction SilentlyContinue)
}

function Test-OpSignedIn {
    if ($env:OP_MOCK -eq '1') { return $true }
    if (-not (Test-OpAvailable)) { return $false }
    try {
        & op whoami *>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Assert-OpSignedIn {
    if (Test-OpSignedIn) { return }
    Write-DevenvError "1Password CLI is not signed in. Run:  op signin"
    Write-DevenvError "Make sure the desktop app is open and 'Integrate with 1Password CLI' is enabled."
    throw '1Password CLI signin required'
}

function Read-OpSecret {
    param([Parameter(Mandatory)][string]$Path)
    if ($env:OP_MOCK -eq '1') { return 'mock-value' }
    Assert-OpSignedIn
    return (& op read $Path)
}

function Invoke-OpInject {
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath
    )
    if ($env:OP_MOCK -eq '1') {
        Copy-Item -Path $InputPath -Destination $OutputPath -Force
        return
    }
    Assert-OpSignedIn
    & op inject -i $InputPath -o $OutputPath
    if ($LASTEXITCODE -ne 0) { throw "op inject failed (exit $LASTEXITCODE)" }
}
