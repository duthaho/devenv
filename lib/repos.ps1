Set-StrictMode -Version Latest

function Get-DevenvReposDefaultPath {
    param([Parameter(Mandatory)][string]$Remote)
    $base = ($Remote -split '/')[-1]
    if ($base.EndsWith('.git')) { $base = $base.Substring(0, $base.Length - 4) }
    return (Join-Path $env:USERPROFILE (Join-Path 'code' $base))
}

function Get-DevenvReposEntries {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.TrimEnd()
        if ($line -eq '' -or $line.TrimStart().StartsWith('#')) { return }
        $parts  = $line.Split('|', 3)
        $remote = $parts[0].Trim()
        $rawPath = if ($parts.Count -ge 2) { $parts[1].Trim() } else { '' }
        $setup  = if ($parts.Count -ge 3) { $parts[2].Trim() } else { '' }
        if (-not $rawPath) {
            $resolved = Get-DevenvReposDefaultPath -Remote $remote
        } elseif ($rawPath.StartsWith('~/')) {
            $resolved = Join-Path $env:USERPROFILE $rawPath.Substring(2)
        } else {
            $resolved = $rawPath
        }
        [pscustomobject]@{ Remote = $remote; Path = $resolved; Setup = $setup }
    } | Where-Object { $_ }
}

function Invoke-DevenvReposSyncOne {
    param(
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Path,
        [string]$Setup = ''
    )
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'git required for repo sync'
        return
    }
    if (Test-Path (Join-Path $Path '.git')) {
        & git -C $Path fetch --tags --prune *>$null
    } else {
        $parent = Split-Path $Path -Parent
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        & git clone --depth 1 $Remote $Path *>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning "clone failed: $Remote"; return }
    }
    if ($Setup -and (Test-Path $Path)) {
        Push-Location $Path
        try { & pwsh -NoProfile -Command $Setup } finally { Pop-Location }
    }
}
