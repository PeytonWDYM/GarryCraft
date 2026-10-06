param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RunRoot,
    [string]$Map = 'gm_construct',
    [string]$JavaHome = "$env:LOCALAPPDATA/GarryCraft/tools/java/jdk-25.0.4.1+1")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$daily = Get-Content -Raw -LiteralPath "$repository/.garrycraft-local.json" | ConvertFrom-Json
$dailyGame = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File $daily.game
$testGame = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$lab/bin/win64/gmod.exe"
if ($testGame -eq $dailyGame) { throw 'CMD tests require a separate game installation.' }
if ($Map -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Use a local map name.' }
$root = Join-Path $RunRoot ([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path "$root/runtime", "$root/launcher/tools", "$root/settings" -Force | Out-Null
[IO.File]::WriteAllText("$root/run-path", '')
$root = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$root/run-path")
& "$PSScriptRoot/Build.ps1" -JavaHome $JavaHome
& "$PSScriptRoot/Install-Lab.ps1" -LabPath $lab
$env:JAVA_HOME = $JavaHome
& "$repository/fabric/gradlew.bat" -p "$repository/fabric" prepareRuntime --no-configuration-cache "-PgarrycraftRuntime=$root/runtime"
if ($LASTEXITCODE) { throw 'CMD lab runtime preparation failed.' }
foreach ($name in 'Runtime.ps1','RuntimeFiles.ps1','RuntimeProcess.ps1') {
    Copy-Item -LiteralPath "$PSScriptRoot/$name" -Destination "$root/runtime/$name"
}
$java = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$JavaHome/bin/java.exe"
@{java=$java;worlds="$root/runtime/worlds";settings="$root/settings"} | ConvertTo-Json |
    Set-Content -LiteralPath "$root/runtime/config.json" -Encoding utf8NoBOM
@{root="$root/runtime".Replace('\','/')} | ConvertTo-Json -Compress |
    Set-Content -LiteralPath "$lab/garrysmod/data/garrycraft-runtime.json" -Encoding utf8NoBOM
foreach ($name in 'garrycraft-runtime-manual.txt','garrycraft-control.json') {
    Remove-Item -LiteralPath "$lab/garrysmod/data/$name" -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath "$repository/GarryCraft.cmd" -Destination "$root/launcher/GarryCraft.cmd"
foreach ($name in 'Launch.ps1','Resolve-LocalPath.ps1') {
    Copy-Item -LiteralPath "$PSScriptRoot/$name" -Destination "$root/launcher/tools/$name"
}
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$root/runtime/GarryCraft.lnk")
$shortcut.TargetPath = $testGame
$shortcut.WorkingDirectory = $lab
$shortcut.Arguments = "-insecure -noworkshop -windowed -w 1280 -h 720 -novid -condebug +sv_lan 1 +maxplayers 1 +exec garrycraft-session.cfg +map $Map"
$shortcut.Save()
@{shortcut="$root/runtime/GarryCraft.lnk";game=$testGame} | ConvertTo-Json |
    Set-Content -LiteralPath "$root/launcher/.garrycraft-local.json" -Encoding utf8NoBOM
Start-Process -FilePath cmd.exe -ArgumentList '/c', "`"$root/launcher/GarryCraft.cmd`"" -WorkingDirectory "$root/launcher" -WindowStyle Hidden
Write-Output "CMD lab directory: $root"
Write-Output "Bridge: $root/runtime/worlds/$Map/bridge.bin"
