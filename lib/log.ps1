# Leveled logging to stderr. Honors $env:DEVENV_LOG_LEVEL (debug|info|warn|error).
# Dot-source me; do not invoke as a script.

function Get-DevenvLogLevelNum {
    param([string]$Name = 'info')
    switch ($Name.ToLowerInvariant()) {
        'debug' { 0 }
        'info'  { 1 }
        'warn'  { 2 }
        'error' { 3 }
        default { 1 }
    }
}

function Write-DevenvLog {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(ValueFromRemainingArguments)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Message
    )
    $want = Get-DevenvLogLevelNum ($env:DEVENV_LOG_LEVEL ?? 'info')
    $have = Get-DevenvLogLevelNum $Level
    if ($have -lt $want) { return }
    $tag = @{ debug='DEBUG'; info='INFO '; warn='WARN '; error='ERROR' }[$Level.ToLowerInvariant()]
    $text = if ($null -eq $Message) { '' } else { ($Message -join ' ') }
    [Console]::Error.WriteLine("$tag $text")
}

function Write-DevenvDebug { Write-DevenvLog -Level debug @Args }
function Write-DevenvInfo  { Write-DevenvLog -Level info  @Args }
function Write-DevenvWarn  { Write-DevenvLog -Level warn  @Args }
function Write-DevenvError { Write-DevenvLog -Level error @Args }
