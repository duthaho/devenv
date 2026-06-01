Set-StrictMode -Version Latest

function Get-DevenvIdeExtensions {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $line
    } | Where-Object { $_ }
}

function Merge-DevenvIdeSettings {
    param(
        [Parameter(Mandatory)][string]$OverlayPath,
        [Parameter(Mandatory)][string]$UserPath
    )
    $parent = Split-Path $UserPath -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $overlayObj = Get-Content $OverlayPath -Raw | ConvertFrom-Json -AsHashtable
    $userObj = @{}
    if ((Test-Path $UserPath) -and (Get-Item $UserPath).Length -gt 0) {
        $userObj = Get-Content $UserPath -Raw | ConvertFrom-Json -AsHashtable
    }
    foreach ($k in $overlayObj.Keys) { $userObj[$k] = $overlayObj[$k] }
    ($userObj | ConvertTo-Json -Depth 16) | Set-Content -Path $UserPath -Encoding UTF8
}

function Invoke-DevenvIdeInstallExtensions {
    param(
        [Parameter(Mandatory)][string]$Cli,
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Get-Command $Cli -ErrorAction SilentlyContinue)) { return }
    foreach ($id in (Get-DevenvIdeExtensions -Path $Path)) {
        & $Cli --install-extension $id --force *>$null
    }
}
