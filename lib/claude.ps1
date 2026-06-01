Set-StrictMode -Version Latest

function Get-DevenvClaudePluginPacks {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $line
    } | Where-Object { $_ }
}

function Install-DevenvClaudeMcpServers {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Warning 'claude not on PATH; skipping mcp add-json'
        return
    }
    $entries = @(Get-Content -Path $Path -Raw | ConvertFrom-Json)
    foreach ($entry in $entries) {
        $json = $entry.json | ConvertTo-Json -Depth 16 -Compress
        & claude mcp add-json $entry.name $json *>$null
    }
}

function Invoke-DevenvClaudeClonePluginPacks {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning 'git required for plugin packs'
        return
    }
    $cache = if ($env:DEVENV_CLAUDE_CACHE_DIR) { $env:DEVENV_CLAUDE_CACHE_DIR } else { Join-Path $env:USERPROFILE '.claude/plugins/cache' }
    foreach ($entry in (Get-DevenvClaudePluginPacks -Path $Path)) {
        $repo = $entry.Split('#', 2)[0]
        $ref  = if ($entry.Contains('#')) { $entry.Split('#', 2)[1] } else { '' }
        $target = Join-Path $cache $repo
        if (Test-Path (Join-Path $target '.git')) {
            & git -C $target fetch --depth 1 origin ($(if ($ref) { $ref } else { 'HEAD' })) *>$null
        } else {
            $parent = Split-Path $target -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            & git clone --depth 1 "https://github.com/$repo.git" $target *>$null
            if ($ref -and (Test-Path (Join-Path $target '.git'))) {
                & git -C $target checkout $ref *>$null
            }
        }
    }
}
