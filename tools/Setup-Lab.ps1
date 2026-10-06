param(
    [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab",
    [string]$RuntimeRoot = "$env:LOCALAPPDATA\GarryCraft\runtime",
    [string]$JavaHome = "$env:LOCALAPPDATA\GarryCraft\tools\java\jdk-25.0.4.1+1",
    [string]$SettingsPath = "$env:LOCALAPPDATA\GarryCraft\settings",
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if (-not $SkipBuild) { & "$PSScriptRoot/Build.ps1" -JavaHome $JavaHome }
& "$PSScriptRoot/Install-Lab.ps1" -LabPath $LabPath
foreach ($name in 'garrycraft-runtime-manual.txt', 'garrycraft-control.json') {
    $previousControl = Join-Path "$LabPath/garrysmod/data" $name
    if (Test-Path -LiteralPath $previousControl) { Remove-Item -LiteralPath $previousControl }
}
$root = [IO.Path]::GetFullPath($RuntimeRoot)
New-Item -ItemType Directory -Path $root -Force | Out-Null
[IO.File]::WriteAllText("$root/setup-path", '')
$root = Split-Path -Parent ((& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$root/setup-path"))
$LabPath = Split-Path -Parent ((& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab"))
$java = (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$JavaHome/bin/java.exe")
$env:JAVA_HOME = $JavaHome
& "$repository/fabric/gradlew.bat" -p "$repository/fabric" prepareRuntime --no-configuration-cache "-PgarrycraftRuntime=$root"
if ($LASTEXITCODE) { throw 'Minecraft runtime preparation failed.' }
Copy-Item -LiteralPath "$PSScriptRoot/Runtime.ps1" -Destination "$root/Runtime.ps1" -Force
Copy-Item -LiteralPath "$PSScriptRoot/RuntimeFiles.ps1" -Destination "$root/RuntimeFiles.ps1" -Force
Copy-Item -LiteralPath "$PSScriptRoot/RuntimeProcess.ps1" -Destination "$root/RuntimeProcess.ps1" -Force
New-Item -ItemType Directory -Path "$root/worlds", $SettingsPath -Force | Out-Null
[IO.File]::WriteAllText("$SettingsPath/setup-path", '')
$settings = Split-Path -Parent ((& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$SettingsPath/setup-path"))
@{java = $java; worlds = "$root/worlds"; settings = $settings} |
    ConvertTo-Json | Set-Content -LiteralPath "$root/config.json" -Encoding utf8NoBOM
@{root = $root.Replace('\', '/')} | ConvertTo-Json -Compress |
    Set-Content -LiteralPath "$LabPath/garrysmod/data/garrycraft-runtime.json" -Encoding utf8NoBOM
# A one-click shortcut starts the host. The addon starts Minecraft after map entry.
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$root/GarryCraft.lnk")
$shortcut.TargetPath = "$LabPath/bin/win64/gmod.exe"
$shortcut.WorkingDirectory = $LabPath
$shortcut.Arguments = '-insecure -windowed -w 1920 -h 1080 -novid +sv_lan 1 +maxplayers 1 +exec garrycraft-session.cfg'
$shortcut.Save()
@{shortcut = "$root/GarryCraft.lnk"; game = $shortcut.TargetPath} | ConvertTo-Json |
    Set-Content -LiteralPath "$repository/.garrycraft-local.json" -Encoding utf8NoBOM
Write-Output "Setup complete. Open $root/GarryCraft.lnk and load a single-player map."
Write-Output "You can also open $repository/GarryCraft.cmd."
Write-Output 'Use Spawn Menu > Utilities > GarryCraft, or garrycraft_menu, to turn the bridge off.'
