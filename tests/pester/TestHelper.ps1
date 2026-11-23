# Shared Pester helper — dot-source from each Tests file.
$Script:DevenvRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../')).Path
$env:DEVENV_ROOT  = $Script:DevenvRoot

function Invoke-WebRequest { throw "network call in unit test: Invoke-WebRequest $args" }
function Invoke-RestMethod { throw "network call in unit test: Invoke-RestMethod $args" }
function npm { throw "network call in unit test: npm $args" }
function winget { throw "network call in unit test: winget $args" }

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
