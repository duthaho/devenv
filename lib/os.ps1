# OS detection. Dot-source me.

function Get-DevenvOs {
    if ($IsWindows) { return 'windows' }
    if ($IsMacOS)   { return 'mac' }
    if ($IsLinux) {
        $procVer = '/proc/version'
        if (Test-Path $procVer) {
            $line = Get-Content $procVer -ErrorAction SilentlyContinue
            if ($line -match '(?i)microsoft') { return 'wsl' }
        }
        return 'linux'
    }
    return 'unknown'
}

function Update-DevenvPath {
    # Refresh $env:PATH from the Windows machine + user environment registries.
    # Needed after `winget install` registers new tool locations that aren't
    # visible to the running process yet.
    if (-not $IsWindows) { return }
    $machine = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('PATH', 'User')
    # Keep session-only entries such as mise shims while adding locations
    # registered by an installer. Select-Object -Unique preserves first-seen
    # order, so the process PATH continues to take precedence.
    $paths = @($env:PATH, $machine, $user)
    $segments = @($paths |
        ForEach-Object { if ($_){ $_ -split ';' } } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique)
    $env:PATH = $segments -join ';'
}

function Get-DevenvDistro {
    $os = Get-DevenvOs
    if ($os -ne 'linux' -and $os -ne 'wsl') { return '' }
    $osRelease = '/etc/os-release'
    if (-not (Test-Path $osRelease)) { return 'unknown' }
    $line = (Get-Content $osRelease | Where-Object { $_ -match '^ID=' } | Select-Object -First 1)
    if (-not $line) { return 'unknown' }
    $id = ($line -replace '^ID=', '').Trim('"').Trim("'")
    if ($id -in @('ubuntu','debian','fedora','rhel','centos','arch','manjaro','alpine')) { return $id }
    return 'unknown'
}
