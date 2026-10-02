param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function State { & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin" }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Minecraft-Command($Command) {
    $literal = $Command.Replace('\', '\\').Replace("'", "\'")
    @"
local GC=GarryCraft
local previous=GC.TestClientControls
local started=RealTime()
GC.TestClientControls=function(controls)
    controls.chat=RealTime()-started<.15
    controls.attack=false controls.use=false
end
timer.Simple(.75,function() GC.QueueUiEvent(0,'/$literal') GC.QueueUiEvent(40) end)
timer.Simple(1.5,function() GC.TestClientControls=previous end)
"@ | Set-Content "$data/garrycraft-architecture-chat.lua" -Encoding utf8NoBOM
    Send "lua_run_cl RunString(file.Read('garrycraft-architecture-chat.lua','DATA'))"
    Start-Sleep -Seconds 2
}
$initial = State
if (-not $initial.linked) { throw 'Architecture tests require a fresh linked Minecraft world with cheats enabled.' }
$bx = [int][Math]::Floor($initial.x) + 2
$by = [int][Math]::Floor($initial.y) + 2
$bz = [int][Math]::Floor($initial.z)
$farX = [int][Math]::Floor($initial.x) + 64
$checks = [ordered]@{}
$samples = @()
Copy-Item "$PSScriptRoot/../tests/architecture.lua" "$data/garrycraft-architecture-fixture.lua"
Send "lua_run RunString(file.Read('garrycraft-architecture-fixture.lua','DATA'))"
function Snapshot($Name) {
    $filename = "garrycraft-architecture-$Name.json"
    if (Test-Path -LiteralPath "$data/$filename") { Remove-Item -LiteralPath "$data/$filename" }
    Send "lua_run GarryCraft.ArchitectureTest.Snapshot('$Name',$bx,$by,$bz)"
    Wait-Until "Source snapshot $Name" { Test-Path -LiteralPath "$data/$filename" }
    Copy-Item "$data/$filename" -Destination $artifacts
    $state = State
    $state | ConvertTo-Json -Depth 12 | Set-Content "$artifacts/minecraft-architecture-$Name.json"
    $script:samples += @{phase = $Name; session = $state.session; instance = $state.renderInstance; frame = $state.frame}
    Get-Content "$data/$filename" -Raw | ConvertFrom-Json
}
try {
    Minecraft-Command 'gamemode creative'
    Minecraft-Command "setblock $bx $by $bz minecraft:stone"
    Wait-Until 'initial block collision' { (Snapshot 'initial').hostCollision }
    $checks.initialCollision = $true
    Minecraft-Command "tp @s $farX $($initial.y) $($initial.z)"
    Wait-Until 'outside the section export radius' { (State).x -ge $farX - 1 }
    Minecraft-Command "setblock $bx $by $bz minecraft:air"
    Start-Sleep -Seconds 2
    $away = Snapshot 'off-range-edit'
    Minecraft-Command "tp @s $($initial.x) $($initial.y) $($initial.z)"
    Wait-Until 'player return' { [Math]::Abs((State).x - $initial.x) -lt 1 }
    Wait-Until 'removed block collision after return' { -not (Snapshot 'returned').hostCollision }
    $checks.lastBlockRemoval = $true
    $checks.sessionRetained = (State).session -eq $initial.session
} finally {
    Minecraft-Command "setblock $bx $by $bz minecraft:air"
    Minecraft-Command "tp @s $($initial.x) $($initial.y) $($initial.z)"
    Minecraft-Command "gamemode $($initial.gameMode)"
    @{checks = $checks; samples = $samples} | ConvertTo-Json -Depth 12 | Set-Content "$artifacts/architecture-result.json"
}
if ($checks.Values -contains $false) { throw "Architecture checks failed. Read $artifacts/architecture-result.json" }
Write-Output "Off-range section checks passed. Artifact: $artifacts/architecture-result.json"
