# External CLI manifest helpers. Dot-source me.
$script:DevenvVersionsRoot = Split-Path -Parent $PSScriptRoot
function Get-DevenvToolVersionsFile { if ($env:DEVENV_TOOL_VERSIONS_FILE) { $env:DEVENV_TOOL_VERSIONS_FILE } else { Join-Path $script:DevenvVersionsRoot 'config/tool-versions.txt' } }
function Get-DevenvToolSetting { param([string]$Tool,[string]$Field) $key="$Tool.$Field"; foreach ($line in [IO.File]::ReadAllLines((Get-DevenvToolVersionsFile))) { if ($line -and -not $line.StartsWith('#') -and $line.Split('=',2)[0] -eq $key) { return $line.Split('=',2)[1] } }; throw "E_MISSING $key" }
function Test-DevenvToolVersions {
    $errors = @(); $seen = @{}; $entries = @{}; $lineNumber = 0
    foreach ($line in [IO.File]::ReadAllLines((Get-DevenvToolVersionsFile))) {
        $lineNumber++
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^[a-z0-9-]+\.[a-z0-9._-]+=[^\s]*$') { $errors += "E_SYNTAX line $lineNumber"; continue }
        $pair = $line.Split('=', 2); $key = $pair[0]; $parts = $key.Split('.', 2)
        if ($seen[$key]) { $errors += "E_DUPLICATE $key" }; $seen[$key] = $true
        if ($parts[1] -notin 'module','source','package','version','sha256.linux-x86_64','sha256.linux-aarch64','sha256.macos','sha256.windows') { $errors += "E_UNKNOWN_FIELD $key" }
        if (-not $entries[$parts[0]]) { $entries[$parts[0]] = @{} }
        $entries[$parts[0]][$parts[1]] = $pair[1]
    }
    foreach ($tool in $entries.Keys) {
        $entry = $entries[$tool]
        foreach ($field in 'module','source','version') { if (-not $entry[$field]) { $errors += "E_MISSING $tool.$field" } }
        if (-not (Test-Path (Join-Path $script:DevenvVersionsRoot "modules/$($entry['module'])"))) { $errors += "E_BAD_MODULE $tool" }
        if ($entry['source'] -notin 'npm','release') { $errors += "E_BAD_SOURCE $tool" }
        if ($entry['source'] -eq 'npm' -and -not $entry['package']) { $errors += "E_MISSING $tool.package" }
        if ($entry['version'] -ne 'latest' -and $entry['version'] -notmatch '^\d+\.\d+\.\d+$') { $errors += "E_BAD_VERSION $tool" }
        $shaKeys = @($entry.Keys | Where-Object { $_ -like 'sha256.*' })
        if ($entry['version'] -eq 'latest' -and $shaKeys.Count) { $errors += "E_SHA_ON_LATEST $tool" }
        if ($entry['source'] -eq 'npm' -and $shaKeys.Count) { $errors += "E_SHA_ON_NPM $tool" }
        if ($entry['source'] -eq 'release' -and $entry['version'] -ne 'latest') {
            foreach ($artifact in 'linux-x86_64','linux-aarch64','macos','windows') {
                $sha = $entry["sha256.$artifact"]
                if (-not $sha) { $errors += "E_MISSING_SHA $tool.$artifact" }
                elseif ($sha -notmatch '^[0-9a-f]{64}$') { $errors += "E_BAD_SHA $tool.$artifact" }
            }
        }
    }
    foreach ($error in $errors) { [Console]::Error.WriteLine($error) }
    return ($errors.Count -eq 0)
}
function Get-DevenvNpmSpec { param([string]$Tool) $p=Get-DevenvToolSetting $Tool package; $v=Get-DevenvToolSetting $Tool version; if($v -eq 'latest'){$p}else{"$p@$v"} }
function Get-DevenvAwsCliUrl { param([string]$Artifact) $v=Get-DevenvToolSetting awscli version; $suffix=if($v -eq 'latest'){''}else{"-$v"}; switch($Artifact){'linux-x86_64'{"https://awscli.amazonaws.com/awscli-exe-linux-x86_64$suffix.zip"}'linux-aarch64'{"https://awscli.amazonaws.com/awscli-exe-linux-aarch64$suffix.zip"}'macos'{"https://awscli.amazonaws.com/AWSCLIV2$suffix.pkg"}'windows'{"https://awscli.amazonaws.com/AWSCLIV2$suffix.msi"}} }
function Test-DevenvSha256 { param([string]$Path,[string]$Tool,[string]$Artifact) if((Get-DevenvToolSetting $Tool version) -eq 'latest'){return}; $expected=Get-DevenvToolSetting $Tool "sha256.$Artifact"; $actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLower(); if($actual -ne $expected){Remove-Item -Force $Path -ErrorAction SilentlyContinue; throw "E_BAD_SHA $Tool.$Artifact"} }
function Get-DevenvToolDrift { param([string]$Tool,[string]$InstalledOutput) $v=Get-DevenvToolSetting $Tool version; if($v -eq 'latest'){return}; $m=[regex]::Match($InstalledOutput,'\d+\.\d+\.\d+'); if(-not $m.Success -or $m.Value -ne $v){"pinned $v, installed $(if($m.Success){$m.Value}else{'unknown'})"} }
function Get-DevenvToolManifestLines { param([string]$Module) foreach($line in [IO.File]::ReadAllLines((Get-DevenvToolVersionsFile))){if($line -and -not $line.StartsWith('#')){$tool=$line.Split('.',2)[0]; try{if((Get-DevenvToolSetting $tool module) -eq $Module){"$line`n"}}catch{Write-Verbose "Ignoring incomplete manifest tool $tool"}}} }
