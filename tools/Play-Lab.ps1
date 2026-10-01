param(
    [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab",
    [string]$RunRoot = "$env:LOCALAPPDATA\GarryCraft\play-lab",
    [string]$JavaHome = "$env:LOCALAPPDATA\GarryCraft\tools\java\jdk-25.0.4.1+1",
    [switch]$FreshWorld,
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
& "$PSScriptRoot\Build.ps1" -JavaHome $JavaHome
& "$PSScriptRoot\Install-Lab.ps1" -LabPath $LabPath
$root = [IO.Path]::GetFullPath($RunRoot)
if ($FreshWorld) { $root = Join-Path $root ([DateTime]::Now.ToString('yyyyMMdd-HHmmss')) }
New-Item -ItemType Directory -Path "$root\minecraft","$root\artifacts" -Force | Out-Null
$launcher = Join-Path $root 'minecraft.ps1'
$repoLiteral = $repository.Replace("'", "''")
$javaLiteral = $JavaHome.Replace("'", "''")
$rootLiteral = $root.Replace("'", "''")
@"
`$env:JAVA_HOME = '$javaLiteral'
Set-Location -LiteralPath '$repoLiteral'
& .\fabric\gradlew.bat -p fabric runClient '-PgarrycraftRunDir=$rootLiteral\minecraft' '-PgarrycraftBridge=$rootLiteral\bridge.bin' '-PgarrycraftArtifacts=$rootLiteral\artifacts'
"@ | Set-Content -LiteralPath $launcher
@{id = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); command = 'start'; bridge = "$root\bridge.bin".Replace('\', '/')} |
    ConvertTo-Json -Compress | Set-Content -LiteralPath "$LabPath\garrysmod\data\garrycraft-control.json"
Start-Process -FilePath pwsh -ArgumentList @('-NoProfile','-File',"`"$launcher`"") -WindowStyle Hidden `
    -RedirectStandardOutput "$root\minecraft-stdout.log" -RedirectStandardError "$root\minecraft-stderr.log"
Start-Process -FilePath "$LabPath\bin\win64\gmod.exe" -WorkingDirectory $LabPath `
    -ArgumentList @('-insecure','-noworkshop','-windowed','-w','1280','-h','720','-novid','-condebug','+sv_lan','1','+maxplayers','1','+map','gm_construct')
if ($Test) {
    $deadline = [DateTime]::UtcNow.AddMinutes(2)
    do {
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath "$root\bridge.bin") {
            try { $state = & "$PSScriptRoot\Observe.ps1" -Bridge "$root\bridge.bin" } catch { $state = $null }
        }
    } until (($state.linked -and $state.geometryReady) -or [DateTime]::UtcNow -gt $deadline)
    if (-not ($state.linked -and $state.geometryReady)) { throw 'The games did not connect. Read the launch logs.' }
    @{id = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); command = 'test'; scenario = 'entities'; bridge = "$root\bridge.bin".Replace('\','/')} |
        ConvertTo-Json -Compress | Set-Content -LiteralPath "$LabPath\garrysmod\data\garrycraft-control.json"
}
Write-Output "Run directory: $root"
Write-Output "Artifacts: $root\artifacts"
