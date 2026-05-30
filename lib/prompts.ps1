# TUI prompts. Dot-source me.

function Confirm-DevenvPrompt {
    param([Parameter(Mandatory)][string]$Question)
    if ($env:DEVENV_NON_INTERACTIVE -eq '1') { return $false }
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        & gum confirm $Question
        return ($LASTEXITCODE -eq 0)
    }
    $ans = Read-Host "$Question [y/N]"
    return ($ans -match '^(y|yes)$')
}

function Read-DevenvInput {
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$Default = ''
    )
    if ($env:DEVENV_NON_INTERACTIVE -eq '1') { return $Default }
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        return (& gum input --prompt "$Label > " --value $Default)
    }
    $shown = if ($Default) { "$Label [$Default]" } else { $Label }
    $ans = Read-Host $shown
    if ([string]::IsNullOrEmpty($ans)) { return $Default }
    return $ans
}
