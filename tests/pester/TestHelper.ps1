# Shared Pester helper — dot-source from each Tests file.
$Script:DevenvRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../')).Path
$env:DEVENV_ROOT  = $Script:DevenvRoot

function New-DevenvTestSandbox {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "devenv-test-$([guid]::NewGuid().Guid)"
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $env:DEVENV_CACHE_DIR = Join-Path $tmp 'cache'
    New-Item -ItemType Directory -Path $env:DEVENV_CACHE_DIR | Out-Null
    return $tmp
}

function Remove-DevenvTestSandbox {
    param([string]$Path)
    if ($Path -and (Test-Path $Path)) { Remove-Item -Recurse -Force $Path }
}
