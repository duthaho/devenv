#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path "$Here/../..").Path
. "$Root/lib/log.ps1"
. "$Root/lib/os.ps1"
. "$Root/lib/op.ps1"
. "$Root/lib/prompts.ps1"

$os = Get-DevenvOs

# Refresh PATH from registry up front — earlier modules' winget installs
# (git, gh, jq, gum) added entries that aren't yet visible to this subprocess.
Update-DevenvPath

if ($os -ne 'windows') {
    Write-DevenvInfo "Delegating 10-1password to run.sh for OS=$os"
    & bash "$Here/run.sh"
    if ($LASTEXITCODE -ne 0) { throw "run.sh failed with exit $LASTEXITCODE" }
    return
}

if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-DevenvInfo 'winget install AgileBits.1Password.CLI'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id AgileBits.1Password.CLI | Out-Null
}
$desktop = winget list --id AgileBits.1Password 2>$null
if (-not ($desktop -match '1Password')) {
    Write-DevenvInfo 'winget install AgileBits.1Password'
    & winget install --silent --accept-source-agreements --accept-package-agreements --source winget --id AgileBits.1Password | Out-Null
}

# Refresh PATH from the registry so the freshly installed `op` is visible
# in this running process (winget updates registry, not the current $env:PATH).
Update-DevenvPath

if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    Write-DevenvError "op CLI installed but not found on PATH. Open a new terminal and re-run, or add 'C:\Program Files\1Password CLI' to PATH manually."
    throw 'op not on PATH after install'
}

if (-not (Test-OpSignedIn)) {
    Write-DevenvInfo ''
    Write-DevenvInfo '============================================================'
    Write-DevenvInfo 'Manual step: open the 1Password desktop app and'
    Write-DevenvInfo "  1) Sign in to your account."
    Write-DevenvInfo "  2) Settings -> Developer -> 'Integrate with 1Password CLI'  [x]"
    Write-DevenvInfo "  3) Settings -> Developer -> 'Use the SSH agent'              [x]"
    Write-DevenvInfo '============================================================'
    if (Confirm-DevenvPrompt 'Ready to verify (op whoami)?') {
        & op whoami *>$null
        if ($LASTEXITCODE -ne 0) {
            Write-DevenvInfo 'Running: op signin'
            & op signin
        }
    }
}

Assert-OpSignedIn

$sshDir = Join-Path $HOME '.ssh'
$confDir = Join-Path $sshDir 'config.d'
New-Item -ItemType Directory -Path $confDir -Force | Out-Null

$snippet = Join-Path $confDir '10-1password.conf'
$agent   = '\\.\pipe\openssh-ssh-agent'
Set-Content -Path $snippet -Value @"
# Managed by devenv module 10-1password. Do not edit by hand.
Host *
  IdentityAgent "$agent"
"@

$mainConf = Join-Path $sshDir 'config'
$includeLine = 'Include ~/.ssh/config.d/*.conf'
$has = (Test-Path $mainConf) -and ((Get-Content $mainConf -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($includeLine))
if (-not $has) {
    Write-DevenvInfo "Adding Include line to $mainConf"
    $existing = if (Test-Path $mainConf) { Get-Content $mainConf -Raw } else { '' }
    Set-Content -Path $mainConf -Value "$includeLine`n$existing"
}

$whoami = if ($env:OP_MOCK -eq '1') { 'mock' } else { (& op whoami 2>$null | Select-Object -First 1) }
Write-DevenvInfo "10-1password: done. Signed in as: $whoami"
