# Curated first-run menu: pick optional modules + language toolchains.
# Dot-source me. Assumes lib/log.ps1 and lib/markers.ps1 are dot-sourced.

$script:DevenvMenuModules        = @('50-ide','60-claude','70-repos','80-gui')
$script:DevenvMenuModulesDefault = @('50-ide','60-claude','70-repos')
$script:DevenvMenuSkip           = ''

# Get-DevenvMenuLangs <config> — the [tools] keys, in file order.
function Get-DevenvMenuLangs {
    param([Parameter(Mandatory)][string]$ConfigPath)
    if (-not (Test-Path $ConfigPath)) { return @() }
    $inTools = $false
    $keys = @()
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        if ($line -match '^\[tools\]') { $inTools = $true;  continue }
        if ($line -match '^\[')        { $inTools = $false; continue }
        if ($inTools -and $line -match '=') {
            $key = ($line -split '=', 2)[0].Trim()
            if ($key) { $keys += $key }
        }
    }
    return $keys
}

# Test-DevenvFirstRun — true when no *.done markers exist in the cache dir.
function Test-DevenvFirstRun {
    $dir = Get-DevenvCacheDir
    if (-not (Test-Path $dir)) { return $true }
    return -not (Get-ChildItem -Path $dir -Filter '*.done' -File -ErrorAction SilentlyContinue)
}

# Test-DevenvMenuShouldShow [-Reconfigure] — whether to present the menu.
function Test-DevenvMenuShouldShow {
    param([switch]$Reconfigure)
    if ($env:DEVENV_NON_INTERACTIVE -eq '1') { return $false }
    if (-not (Get-Command gum -ErrorAction SilentlyContinue)) { return $false }
    if ($Reconfigure) { return $true }
    if (-not (Test-DevenvFirstRun)) { return $false }
    # First-run auto-show requires an interactive stdin (never in CI / pipes).
    if ([Console]::IsInputRedirected) { return $false }
    return $true
}

# Thin, mockable wrapper over `gum choose`. Throws on a non-zero (cancel) exit.
function Invoke-DevenvGumChoose {
    param(
        [Parameter(Mandatory)][string]$Header,
        [string]$Selected,
        [Parameter(Mandatory)][string[]]$Items
    )
    $out = @(gum choose --no-limit --header $Header --selected $Selected @Items)
    if ($LASTEXITCODE -ne 0) { throw "gum choose cancelled (exit $LASTEXITCODE)" }
    return $out
}

# Invoke-DevenvMenu <config> — present the checklists and translate the choice
# into: $script:DevenvMenuSkip (csv of optional modules to skip),
# $env:DEVENV_LANGS (csv), and $env:DEVENV_GUI_ENABLED=1 iff 80-gui chosen.
# On cancel, leaves those unset so the caller falls back to defaults.
function Invoke-DevenvMenu {
    param([Parameter(Mandatory)][string]$ConfigPath)
    try {
        $chosenMods = @(Invoke-DevenvGumChoose -Header 'Select optional modules' `
            -Selected ($script:DevenvMenuModulesDefault -join ',') -Items $script:DevenvMenuModules)
        $langsAll = @(Get-DevenvMenuLangs $ConfigPath)
        $chosenLangs = @(Invoke-DevenvGumChoose -Header 'Select languages (mise)' `
            -Selected ($langsAll -join ',') -Items $langsAll)
    } catch {
        Write-DevenvWarn "menu: selection cancelled; keeping defaults ($_)"
        return
    }
    $skip = @($script:DevenvMenuModules | Where-Object { $_ -notin $chosenMods })
    $script:DevenvMenuSkip = ($skip -join ',')
    if ('80-gui' -in $chosenMods) { $env:DEVENV_GUI_ENABLED = '1' }
    $env:DEVENV_LANGS = ($chosenLangs -join ',')
}
