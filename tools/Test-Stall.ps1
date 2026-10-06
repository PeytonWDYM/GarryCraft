param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/stall/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/config.json")
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new owned run directory.' }
& "$PSScriptRoot/Install-Lab.ps1" -LabPath $LabPath
New-Item -ItemType Directory -Path "$RunRoot/settings", "$RunRoot/worlds" -Force | Out-Null
[IO.File]::WriteAllText("$RunRoot/owner", 'stall-test')
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/owner")
Copy-Item "$RuntimeRoot/java.args", "$PSScriptRoot/Runtime.ps1", "$PSScriptRoot/RuntimeFiles.ps1" -Destination $RunRoot
$configuration = Get-Content "$RuntimeRoot/config.json" -Raw | ConvertFrom-Json
@{java=$configuration.java; settings="$RunRoot/settings"; worlds="$RunRoot/worlds"} |
    ConvertTo-Json | Set-Content "$RunRoot/config.json" -Encoding utf8NoBOM
"maxFps:60`nenableVsync:false`npauseOnLostFocus:false`nrenderDistance:8`n" |
    Set-Content "$RunRoot/settings/options.txt" -Encoding utf8NoBOM
$data = "$LabPath/garrysmod/data"
$serverSettingsPath = "$LabPath/garrysmod/cfg/server.vdf"
$previousServerSettings = [IO.File]::ReadAllText($serverSettingsPath)
$runtimeConfiguration = "$data/garrycraft-runtime.json"
$previousConfiguration = if (Test-Path $runtimeConfiguration) { [IO.File]::ReadAllText($runtimeConfiguration) } else { $null }
$manual = "$data/garrycraft-runtime-manual.txt"
$previousManual = if (Test-Path $manual) { [IO.File]::ReadAllText($manual) } else { $null }
$game = $null
$java = $null
$suspended = $false
$checks = [ordered]@{}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GarryCraftStall {
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr process);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr process);
}
'@
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $game.Id -LabPath $LabPath -Command $Command }
function Status { Get-Content "$data/garrycraft-runtime-status.json" -Raw | ConvertFrom-Json }
function State { & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/worlds/gm_construct/bridge.bin" }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if (& $Condition) { return }
        if ($game -and $game.HasExited) { throw "Source exited while waiting for $Description" }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Snapshot($Name) {
    $file = "garrycraft-stall-$Name.json"
    if (Test-Path "$data/$file") { Remove-Item -LiteralPath "$data/$file" }
    Send "lua_run file.Write('$file',util.TableToJSON({active=GarryCraft.IsActive(),linked=GarryCraft.IsLinked(),session=player.GetHumans()[1]:GetNWString('GarryCraftSession'),status=GetGlobalString('GarryCraftStatus')}))"
    Wait-Until "snapshot $Name" {
        if (-not (Test-Path "$data/$file")) { return $false }
        try { $value = Get-Content "$data/$file" -Raw | ConvertFrom-Json; return $value.active -is [bool] }
        catch { return $false }
    }
    Copy-Item "$data/$file" -Destination $RunRoot
    Get-Content "$RunRoot/$file" -Raw | ConvertFrom-Json
}
try {
    if (Test-Path $manual) { Remove-Item -LiteralPath $manual }
    @{root=$RunRoot.Replace('\','/')} | ConvertTo-Json | Set-Content $runtimeConfiguration -Encoding utf8NoBOM
    [IO.File]::WriteAllText($serverSettingsPath, ($previousServerSettings -replace '("garrycraft_enabled"\s+")[^"]*(")', '${1}1${2}'))
    $game = Start-Process "$LabPath/bin/win64/gmod.exe" -WorkingDirectory $LabPath -WindowStyle Hidden -PassThru `
        -ArgumentList '-insecure -noworkshop -windowed -w 1280 -h 720 -novid +sv_lan 1 +maxplayers 1 +exec garrycraft-session.cfg +map gm_construct'
    Wait-Until 'fresh world link' {
        (Test-Path "$data/garrycraft-runtime-status.json") -and (Status).hostPid -eq $game.Id -and
            (Status).state -eq 'ready' -and (State).linked -and (State).geometryReady
    }
    $java = Get-Process -Id (Status).javaPid
    $before = Snapshot 'before'
    $frame = (State).frame
    if ([GarryCraftStall]::NtSuspendProcess($java.Handle)) { throw 'Cannot suspend the owned Java process.' }
    $suspended = $true
    Start-Sleep -Seconds 8
    $during = Snapshot 'during'
    $checks.bridgeRetained = [bool]$during.active
    $checks.shutdownNotRequested = -not (Get-Content "$RunRoot/worlds/gm_construct/control.json" -Raw | ConvertFrom-Json).stop
    if ([GarryCraftStall]::NtResumeProcess($java.Handle)) { throw 'Cannot resume the owned Java process.' }
    $suspended = $false
    Wait-Until 'state after resume' { (State).frame -gt $frame }
    $after = Snapshot 'after'
    $checks.sameJava = (Status).javaPid -eq $java.Id -and -not $java.HasExited
    $checks.sameSession = $before.session -eq $after.session
    $checks.bridgeRecovered = $after.active -and $after.linked
    Send 'garrycraft_disable'
    Wait-Until 'normal save and exit' { $java.HasExited -and (Status).state -eq 'off' }
    $checks.cleanExit = $true
    $passed = @($checks.Values | Where-Object { $_ -ne $true }).Count -eq 0
    @{passed=$passed; checks=$checks; javaPid=$java.Id; hostPid=$game.Id; directory=$RunRoot} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/stall-result.json"
    if (-not $passed) { throw 'Stall checks failed. Read stall-result.json.' }
    Get-Content "$RunRoot/stall-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; directory=$RunRoot} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/stall-result.json"
    throw
} finally {
    if ($suspended) { [GarryCraftStall]::NtResumeProcess($java.Handle) | Out-Null }
    if ($game -and -not $game.HasExited) {
        Send 'quit'
        Wait-Until 'Source exit' { $game.HasExited }
    }
    if ($java) { Wait-Until 'Java cleanup' { $java.HasExited }; $java.Dispose() }
    if ($previousConfiguration) { [IO.File]::WriteAllText($runtimeConfiguration, $previousConfiguration) }
    else { Remove-Item -LiteralPath $runtimeConfiguration }
    if ($null -ne $previousManual) { [IO.File]::WriteAllText($manual, $previousManual) }
    [IO.File]::WriteAllText($serverSettingsPath, $previousServerSettings)
}
