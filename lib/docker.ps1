function Get-DevenvComposeMainPath {
    $here = Split-Path -Parent $PSCommandPath
    $root = (Resolve-Path (Join-Path $here '..')).Path
    Join-Path $root 'services/compose.yml'
}

function Get-DevenvComposeLocalPath {
    Join-Path $HOME '.devenv/services/compose.local.yml'
}

function Get-DevenvComposeArgs {
    $a = @('-f', (Get-DevenvComposeMainPath))
    $localPath = Get-DevenvComposeLocalPath
    if (Test-Path $localPath) { $a += @('-f', $localPath) }
    return $a
}

function Get-DevenvDbForProject {
    param([string]$Project)
    "${Project}_dev"
}
