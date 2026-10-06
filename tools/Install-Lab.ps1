param([string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$lab = (Resolve-Path -LiteralPath $LabPath).Path
if (-not (Test-Path -LiteralPath "$lab\.garrycraft-lab")) {
    throw 'This directory has no .garrycraft-lab marker. Use an isolated GarryCraft installation.'
}
$executable = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$lab/bin/win64/gmod.exe"
$running = Get-Process gmod -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File $_.Path) -eq $executable
}
if ($running) { throw 'Close the isolated GarryCraft game before installation.' }
New-Item -ItemType Directory -Path "$lab\garrysmod\lua\bin","$lab\garrysmod\addons\garrycraft\lua" -Force | Out-Null
$addonLua = "$lab\garrysmod\addons\garrycraft\lua"
# Remove retired addon code while retaining game settings, data, and saved worlds.
foreach ($installed in Get-ChildItem -LiteralPath $addonLua -File -Recurse) {
    $relative = $installed.FullName.Substring($addonLua.Length + 1)
    if (-not (Test-Path -LiteralPath "$repository\gmod\lua\$relative")) {
        Remove-Item -LiteralPath $installed.FullName
    }
}
foreach ($realm in @('gmcl', 'gmsv')) {
    Copy-Item -LiteralPath "$repository\native\build\Release\${realm}_garrycraft_win64.dll" -Destination "$lab\garrysmod\lua\bin"
}
Copy-Item -Path "$repository\gmod\lua\*" -Destination "$lab\garrysmod\addons\garrycraft\lua" -Recurse -Force
New-Item -ItemType Directory -Path "$lab/garrysmod/cfg" -Force | Out-Null
Copy-Item -LiteralPath "$repository/gmod/cfg/garrycraft-session.cfg" -Destination "$lab/garrysmod/cfg" -Force
Write-Output "Installed GarryCraft in $lab"
