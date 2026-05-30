# Idempotency markers. Dot-source me.

function Get-DevenvCacheDir {
    if ($env:DEVENV_CACHE_DIR) { return $env:DEVENV_CACHE_DIR }
    return (Join-Path $HOME '.cache/devenv')
}

function Get-DevenvMarkerPath {
    param([Parameter(Mandatory)][string]$Module)
    return (Join-Path (Get-DevenvCacheDir) "$Module.done")
}

function Get-DevenvModuleSha {
    param([Parameter(Mandatory)][string]$ModuleDir)
    if (-not (Test-Path $ModuleDir -PathType Container)) { return '' }
    # Iterate candidates in fixed deterministic order — DO NOT sort.
    # bash `sort` is case-sensitive (ASCII R<d) while PowerShell `Sort-Object`
    # is case-insensitive on Windows. Sorting would produce divergent SHAs
    # across platforms. The candidates list IS the canonical order.
    $candidates = @('run.sh','run.ps1','doctor.sh','doctor.ps1','README.md')
    $files = $candidates |
        ForEach-Object { Join-Path $ModuleDir $_ } |
        Where-Object   { Test-Path $_ -PathType Leaf }
    if (-not $files) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $combined = New-Object System.IO.MemoryStream
    foreach ($f in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($f)
        $combined.Write($bytes, 0, $bytes.Length)
    }
    $hash = $sha.ComputeHash($combined.ToArray())
    return ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Test-DevenvDone {
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][string]$Sha
    )
    $p = Get-DevenvMarkerPath -Module $Module
    if (-not (Test-Path $p -PathType Leaf)) { return $false }
    $got = (Get-Content $p -Raw).Trim()
    return ($got -eq $Sha)
}

function Set-DevenvDone {
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][string]$Sha
    )
    $p = Get-DevenvMarkerPath -Module $Module
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $p -Value $Sha -NoNewline
}

function Clear-DevenvDone {
    param([Parameter(Mandatory)][string]$Module)
    $p = Get-DevenvMarkerPath -Module $Module
    if (Test-Path $p) { Remove-Item -Force $p }
}
