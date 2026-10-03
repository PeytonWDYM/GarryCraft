param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$Command)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$literal = $Command.Replace('\', '\\').Replace("'", "\'")
$request = [Guid]::NewGuid().ToString('N')
@"
local GC=GarryCraft
assert(game.SinglePlayer() and GC.State and GC.State.linked,'Use a linked single-player lab')
local previous=GC.TestClientControls
local started=RealTime()
GC.TestClientControls=function(controls)
    controls.chat=RealTime()-started<.15
    controls.attack=false controls.use=false
end
timer.Simple(.75,function() GC.QueueUiEvent(0,'/$literal') GC.QueueUiEvent(40) end)
timer.Simple(1.5,function()
    GC.TestClientControls=previous
    file.Write('garrycraft-lab-command-result.txt','$request')
end)
"@ | Set-Content "$data/garrycraft-lab-command.lua" -Encoding utf8NoBOM
& "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command "lua_run_cl RunString(file.Read('garrycraft-lab-command.lua','DATA'))"
$deadline = [DateTime]::UtcNow.AddSeconds(10)
do {
    if ((Test-Path -LiteralPath "$data/garrycraft-lab-command-result.txt") -and
        (Get-Content -LiteralPath "$data/garrycraft-lab-command-result.txt" -Raw) -eq $request) {
        Start-Sleep -Milliseconds 500
        return
    }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)
throw 'Minecraft did not acknowledge the lab command. Read the Source console log.'
