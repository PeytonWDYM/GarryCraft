param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [Parameter(Mandatory)][string]$PackageRoot,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/player-addon-tests/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$LabPath/.garrycraft-lab")) { throw 'Use a marked, separate game installation.' }
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/.garrycraft-player")
$configuration = Get-Content "$RuntimeRoot/install.json" -Raw | ConvertFrom-Json
if ($configuration.game -ne $LabPath) { throw 'The player launcher must target the marked lab.' }
if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Close GMod before this test.' }
if (Test-Path $RunRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$probe = "$LabPath/garrysmod/addons/garrycraft-launch-check/lua/autorun/server/garrycraft_launch_check.lua"
if (Test-Path $probe) { throw 'The test addon already exists.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $probe) -Force | Out-Null
$reportId = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')
$reportName = "garrycraft-launch-check-$reportId.json"
$consoleLog = "$LabPath/garrysmod/garrycraft-launch-$reportId.log"
"hook.Add('InitPostEntity','GarryCraftLauncherCheck',function() file.Write('$reportName',util.TableToJSON({addonLoaded=true,singlePlayer=game.SinglePlayer(),map=game.GetMap()})) end)" |
    Set-Content -LiteralPath $probe -Encoding ascii
$checks = [ordered]@{}
$game = $null
try {
    $checks.folderLauncherTargetsPlayer = (Get-Content "$PackageRoot/player.json" -Raw | ConvertFrom-Json).root -eq $RuntimeRoot
    if (-not $checks.folderLauncherTargetsPlayer) { throw 'The folder launcher must target the owned player runtime.' }
    Start-Process -FilePath "$env:WINDIR/System32/cmd.exe" -ArgumentList @('/d', '/c', ('call "' + "$PackageRoot/Play.cmd" + '"')) -WindowStyle Hidden
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        Start-Sleep -Seconds 1
        $game = Get-Process gmod -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq "$LabPath\bin\win64\gmod.exe" -and $_.MainWindowHandle -ne 0 -and $_.Responding } | Select-Object -First 1
    } until ($game -or [DateTime]::UtcNow -gt $deadline)
    if (-not $game) { throw 'The player launcher did not open the owned game.' }
    $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($game.Id)").CommandLine
    $checks.addonsEnabled = $commandLine -notmatch '-noworkshop|-noaddons'
    $commandLine | Set-Content "$RunRoot/launch-command.txt"
    Start-Sleep -Seconds 5
    & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command "con_logfile garrycraft-launch-$reportId.log"
    & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'map gm_construct'
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do { Start-Sleep -Seconds 1 } until ((Test-Path "$LabPath/garrysmod/data/$reportName") -or [DateTime]::UtcNow -gt $deadline)
    $report = Get-Content "$LabPath/garrysmod/data/$reportName" -Raw | ConvertFrom-Json
    Copy-Item "$LabPath/garrysmod/data/$reportName" "$RunRoot/addon-report.json"
    $checks.addonLoaded = $report.addonLoaded
    $checks.singlePlayer = $report.singlePlayer
    & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'garrycraft_enable'
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do {
        Start-Sleep -Seconds 1
        $status = & "$PSScriptRoot/Read-JsonSnapshot.ps1" -Path "$LabPath/garrysmod/data/garrycraft-runtime-status.json"
        $linked = $false
        if ($status.state -eq 'ready') {
            $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/gm_construct/bridge.bin"
            $linked = $state.linked -and $state.geometryReady
        }
    } until ($linked -or [DateTime]::UtcNow -gt $deadline)
    $checks.bridgeLinkedWithGeometry = $linked
    $status | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/bridge-ready.json"
    & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'garrycraft_disable'
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        Start-Sleep -Seconds 1
        $status = & "$PSScriptRoot/Read-JsonSnapshot.ps1" -Path "$LabPath/garrysmod/data/garrycraft-runtime-status.json"
    } until ($status.state -eq 'off' -or [DateTime]::UtcNow -gt $deadline)
    $checks.minecraftStoppedAfterDisable = $status.state -eq 'off'
    $status | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/bridge-stopped.json"
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; directory=$RunRoot} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/player-addons-result.json"
    if (-not $passed) { throw 'Player addon checks failed.' }
    Get-Content "$RunRoot/player-addons-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/player-addons-result.json"
    throw
} finally {
    try {
        if ($game -and (Get-Process -Id $game.Id -ErrorAction SilentlyContinue)) {
            & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'quit'
            $game.WaitForExit(30000) | Out-Null
        }
    } finally {
        Remove-Item -LiteralPath $probe
        if (Test-Path -LiteralPath $consoleLog) { Copy-Item -LiteralPath $consoleLog -Destination "$RunRoot/source-console.log" }
    }
}
