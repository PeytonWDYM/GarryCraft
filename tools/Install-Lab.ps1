param([string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$lab = (Resolve-Path -LiteralPath $LabPath).Path
if (-not (Test-Path -LiteralPath "$lab\.garrycraft-lab")) {
    throw 'This directory has no .garrycraft-lab marker. Use an isolated GarryCraft installation.'
}
$executable = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$lab/bin/win64/gmod.exe"
$running = Get-CimInstance Win32_Process -Filter "name='gmod.exe'" |
    Where-Object { $_.ExecutablePath -and
        (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File $_.ExecutablePath) -eq $executable }
if ($running) { throw 'Close the isolated GarryCraft game before installation.' }
New-Item -ItemType Directory -Path "$lab\garrysmod\lua\bin","$lab\garrysmod\addons\garrycraft\lua" -Force | Out-Null
foreach ($realm in @('gmcl', 'gmsv')) {
    Copy-Item -LiteralPath "$repository\native\build\Release\${realm}_garrycraft_win64.dll" -Destination "$lab\garrysmod\lua\bin"
}
Copy-Item -Path "$repository\gmod\lua\*" -Destination "$lab\garrysmod\addons\garrycraft\lua" -Recurse -Force
Write-Output "Installed GarryCraft in $lab"
