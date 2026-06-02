Set-StrictMode -Version Latest

function Test-DevenvGuiEnabled {
    return ($env:DEVENV_GUI_ENABLED -eq '1')
}

function Test-DevenvGuiWingetJsonHasPackages {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $obj = Get-Content $Path -Raw | ConvertFrom-Json
    if (-not $obj.Sources) { return $false }
    foreach ($src in $obj.Sources) {
        if ($src.Packages -and $src.Packages.Count -gt 0) { return $true }
    }
    return $false
}

function Invoke-DevenvGuiWingetImport {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not (Test-DevenvGuiWingetJsonHasPackages -Path $Path)) { return }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning 'winget not on PATH; skipping import'
        return
    }
    & winget import --import-file $Path --accept-source-agreements --accept-package-agreements *>$null
}
