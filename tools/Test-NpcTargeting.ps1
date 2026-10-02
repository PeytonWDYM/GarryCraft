param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$checks = [ordered]@{}
$samples = @()
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
"@ | Set-Content "$data/garrycraft-targeting-chat.lua" -Encoding utf8NoBOM
    Send "lua_run_cl RunString(file.Read('garrycraft-targeting-chat.lua','DATA'))"
    Start-Sleep -Seconds 2
}
function Mode($Name) {
    Minecraft-Command "gamemode $Name"
    Wait-Until "Minecraft $Name" { (State).gameMode -eq $Name }
}
function Snapshot($Name) {
    $filename = "garrycraft-targeting-$Name.json"
    if (Test-Path "$data/$filename") { Remove-Item -LiteralPath "$data/$filename" }
    Send "lua_run GarryCraft.NpcTargetingTest.phase='$Name' GarryCraft.NpcTargetingTest.Snapshot('$Name')"
    Wait-Until "snapshot $Name" {
        if (-not (Test-Path "$data/$filename")) { return $false }
        try { $snapshot = Get-Content "$data/$filename" -Raw | ConvertFrom-Json; return $null -ne $snapshot.npcs }
        catch { return $false }
    }
    Copy-Item "$data/$filename" -Destination $artifacts
    $state = State
    $state | ConvertTo-Json -Depth 12 | Set-Content "$artifacts/minecraft-$Name.json"
    $script:samples += @{name = $Name; gameMode = $state.gameMode; frame = $state.frame; session = $state.session}
    Get-Content "$artifacts/$filename" -Raw | ConvertFrom-Json
}
function Row($Snapshot, $Name) { $Snapshot.npcs | Where-Object name -eq $Name }
function Restored($Snapshot) {
    @($Snapshot.npcs | Where-Object { $_.disposition -ne $_.original -or $_.priority -ne $_.originalPriority }).Count -eq 0
}
$savedMode = (State).gameMode
try {
    Mode 'survival'
    Copy-Item "$PSScriptRoot/../tests/npc-targeting.lua" "$data/garrycraft-targeting-fixture.lua"
    Send "lua_run RunString(file.Read('garrycraft-targeting-fixture.lua','DATA'))"
    $before = Snapshot 'survival'
    $checks.survivalHostile = (Row $before 'hostile').disposition -eq 1 -and (Row $before 'hostile').enemyOwner
    Mode 'creative'
    $creative = Snapshot 'creative'
    $checks.creativeNoEnemies = @($creative.npcs | Where-Object enemyOwner).Count -eq 0
    $checks.creativeNeutral = (Row $creative 'hostile').disposition -eq 4 -and (Row $creative 'fearful').disposition -eq 4
    $checks.alliesAcknowledge = (Row $creative 'ally').disposition -eq 3 -and (Row $creative 'ally').visible -and -not $creative.noTarget
    $checks.neutralPreserved = (Row $creative 'neutral').priority -eq (Row $before 'neutral').priority
    Send "lua_run GarryCraft.NpcTargetingTest.Spawn('late','npc_zombie')"
    Start-Sleep -Seconds 2
    $late = Snapshot 'late'
    $checks.newNpcProtected = (Row $late 'late').disposition -eq 4 -and -not (Row $late 'late').enemyOwner
    Send 'lua_run local t=GarryCraft.NpcTargetingTest t.hostile:SetEnemy(player.GetHumans()[1]) t.hostile:UpdateEnemyMemory(player.GetHumans()[1],player.GetHumans()[1]:GetPos())'
    Start-Sleep -Seconds 1
    $checks.staleEnemyCleared = -not (Row (Snapshot 'stale') 'hostile').enemyOwner
    Minecraft-Command 'damage @e[name=garrycraft-targeting-hostile,limit=1] 1 minecraft:player_attack by @p'
    $attacked = Snapshot 'attacked'
    $checks.noRetaliation = (Row $attacked 'hostile').health -lt 10000 -and -not (Row $attacked 'hostile').enemyOwner
    # Freeze this control NPC so native AI cannot choose a different enemy between snapshots.
    Send 'lua_run local t=GarryCraft.NpcTargetingTest t.hostile:AddEntityRelationship(t.ally,D_HT,99) t.hostile:SetEnemy(t.ally) t.hostile:UpdateEnemyMemory(t.ally,t.ally:GetPos()) t.hostile:SetSchedule(SCHED_NPC_FREEZE)'
    Start-Sleep -Seconds 1
    $checks.otherEnemyPreserved = (Row (Snapshot 'other') 'hostile').enemyAlly
    Minecraft-Command 'summon minecraft:cow ~2 ~ ~ {NoAI:1b,Tags:["garrycraft_targeting_test"]}'
    Start-Sleep -Seconds 2
    $mob = Snapshot 'mob'
    $checks.hostileStillTargetsMobs = (Row $mob 'hostile').mobs -contains 1
    Mode 'adventure'
    $checks.adventureRestored = Restored (Snapshot 'adventure')
    Mode 'creative'
    Mode 'survival'
    $checks.survivalRestored = Restored (Snapshot 'restored')
    Mode 'creative'
    Send 'garrycraft_stop'
    $stopped = Snapshot 'stopped'
    $checks.stopRestored = -not $stopped.active -and (Restored $stopped)
} finally {
    Send 'lua_run if GarryCraft.NpcTargetingTest then GarryCraft.NpcTargetingTest.Stop() end'
    Send 'garrycraft_start'
    Wait-Until 'reattach' { (State).linked }
    Minecraft-Command 'kill @e[type=minecraft:cow,tag=garrycraft_targeting_test]'
    Mode $savedMode
    $passed = $checks.Count -eq 13 -and -not ($checks.Values -contains $false)
    @{passed = $passed; checks = $checks; samples = $samples} | ConvertTo-Json -Depth 8 |
        Set-Content "$artifacts/npc-targeting-result.json"
}
Get-Content "$artifacts/npc-targeting-result.json"
if (-not $passed) { throw 'NPC targeting checks failed. Read npc-targeting-result.json.' }
