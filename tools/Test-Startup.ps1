param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [Parameter(Mandatory)][int]$GamePid, [string]$CustomMap = 'backrooms_main')
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/config.json")
$artifacts = Join-Path (Split-Path -Parent $RuntimeRoot) 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$checks = [ordered]@{}
$samples = @()
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Status { Get-Content -LiteralPath "$LabPath/garrysmod/data/garrycraft-runtime-status.json" -Raw | ConvertFrom-Json }
function Wait-Linked($Map) {
    Wait-Until "link on $Map" {
        $status = Status
        if ($status.map -ne $Map -or $status.state -ne 'ready') { return $false }
        $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/$Map/bridge.bin"
        return $state.linked -and $state.geometryReady -and $state.session.StartsWith("${Map}:")
    }
    $status = Status
    $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/$Map/bridge.bin"
    $script:samples += @{map=$Map; javaPid=$status.javaPid; session=$state.session; fps=$state.fps; geometryReady=$state.geometryReady}
}
function Snapshot($Name) {
    $filename = "garrycraft-startup-$Name.json"
    $probe = "garrycraft-startup-$Name.lua"
    if (Test-Path -LiteralPath "$LabPath/garrysmod/data/$filename") { Remove-Item -LiteralPath "$LabPath/garrysmod/data/$filename" }
    "local p=player.GetHumans()[1] file.Write('$filename',util.TableToJSON({map=game.GetMap(),active=GarryCraft.IsActive(),linked=GarryCraft.IsLinked(),moveType=p:GetMoveType(),weapon=p:GetActiveWeapon():GetClass(),health=p:Health(),armor=p:Armor(),collisionGroup=p:GetCollisionGroup(),bridgeWeapon=p:HasWeapon('weapon_garrycraft'),blocks=#ents.FindByClass('gc_block'),bullseyes=#ents.FindByClass('npc_bullseye')}))" |
        Set-Content -LiteralPath "$LabPath/garrysmod/data/$probe" -Encoding utf8NoBOM
    Send "lua_run RunString(file.Read('$probe','DATA'))"
    Wait-Until "snapshot $Name" { Test-Path -LiteralPath "$LabPath/garrysmod/data/$filename" }
    Copy-Item -LiteralPath "$LabPath/garrysmod/data/$filename" -Destination $artifacts
    Get-Content -LiteralPath "$artifacts/$filename" -Raw | ConvertFrom-Json
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
"@ | Set-Content -LiteralPath "$LabPath/garrysmod/data/garrycraft-startup-chat.lua" -Encoding utf8NoBOM
    Send "lua_run_cl RunString(file.Read('garrycraft-startup-chat.lua','DATA'))"
    Start-Sleep -Seconds 2
}
try {
    Send 'garrycraft_enable'
    Wait-Linked 'gm_construct'
    $firstPid = (Status).javaPid
    Send 'garrycraft_enable'
    Send 'garrycraft_enable'
    Start-Sleep -Seconds 1
    $checks.duplicateEnable = (Status).javaPid -eq $firstPid
    Send 'garrycraft_disable'
    Wait-Until 'Minecraft save and exit' { (Status).state -eq 'off' }
    Send 'lua_run_cl garrycraft_bridge.cap(GetConVar("fps_max"),144) garrycraft_bridge.cap(GetConVar("fps_max_nofocus"),72)'
    Send 'lua_run local p=player.GetHumans()[1] p:Give("weapon_projectile") p:SelectWeapon("weapon_projectile")'
    Start-Sleep -Milliseconds 500
    $before = Snapshot 'before'
    Send 'garrycraft_enable'
    Wait-Linked 'gm_construct'
    $checks.addonPresent = $before.weapon -eq 'weapon_projectile'
    $enabled = Snapshot 'enabled'
    $checks.enabled = $enabled.active -and $enabled.linked
    $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/gm_construct/bridge.bin"
    $block = '{0} {1} {2}' -f [Math]::Floor($state.x+2), [Math]::Floor($state.y+2), [Math]::Floor($state.z+2)
    Minecraft-Command "setblock $block minecraft:diamond_block"
    $marker = 'GC_SAVED_' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Send 'garrycraft_disable'
    Wait-Until 'second save and exit' { (Status).state -eq 'off' }
    Start-Sleep -Milliseconds 500
    $after = Snapshot 'disabled'
    $checks.restoredPlayer = $after.weapon -eq $before.weapon -and $after.moveType -eq $before.moveType -and
        $after.health -eq $before.health -and $after.armor -eq $before.armor -and $after.collisionGroup -eq $before.collisionGroup
    $checks.cleanedEntities = -not $after.active -and -not $after.bridgeWeapon -and $after.blocks -eq 0 -and $after.bullseyes -eq 0
    if (Test-Path -LiteralPath "$LabPath/garrysmod/data/garrycraft-startup-client.json") {
        Remove-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-startup-client.json"
    }
    Send "lua_run_cl file.Write('garrycraft-startup-client.json',util.TableToJSON({fps=GetConVar('fps_max'):GetInt(),noFocusFps=GetConVar('fps_max_nofocus'):GetInt(),inactive=not LocalPlayer():GetNWBool('GarryCraft'),stateCleared=GarryCraft.State==nil,overlayCleared=not GarryCraft.OverlayReady}))"
    Wait-Until 'client restore report' { Test-Path -LiteralPath "$LabPath/garrysmod/data/garrycraft-startup-client.json" }
    Copy-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-startup-client.json" -Destination $artifacts
    $client = Get-Content "$artifacts/garrycraft-startup-client.json" -Raw | ConvertFrom-Json
    $checks.clientRestored = $client.inactive -and $client.stateCleared -and $client.overlayCleared
    $checks.frameLimitsRestored = $client.fps -eq 144 -and $client.noFocusFps -eq 72
    $configuration = Get-Content "$RuntimeRoot/config.json" -Raw | ConvertFrom-Json
    $optionsPath = Join-Path $configuration.settings 'options.txt'
    Copy-Item -LiteralPath $optionsPath -Destination "$artifacts/options-before.txt"
    $options = [IO.File]::ReadAllText($optionsPath) -replace '(?m)^maxFps:.*$', 'maxFps:180'
    [IO.File]::WriteAllText($optionsPath, $options)
    Send 'garrycraft_enable'
    Wait-Linked 'gm_construct'
    $checks.sameWorld = Test-Path -LiteralPath "$RuntimeRoot/worlds/gm_construct/minecraft/saves/GarryCraft/level.dat"
    Minecraft-Command "execute if block $block minecraft:diamond_block run say $marker"
    $worldLog = "$RuntimeRoot/worlds/gm_construct/minecraft-stdout.log"
    Wait-Until 'saved block after reopening' { (Get-Content -LiteralPath $worldLog -Raw).Contains("[GarryCraft] $marker") }
    $checks.savedBlock = $true
    Get-Content -LiteralPath $worldLog -Raw | Set-Content "$artifacts/persistence-minecraft.log"
    Wait-Until 'saved Minecraft FPS setting' {
        $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/gm_construct/bridge.bin"
        $state.fps -ge 100 -and $state.fps -le 185
    }
    $checks.savedSetting = $true
    Send 'changelevel gm_flatgrass'
    Wait-Linked 'gm_flatgrass'
    $checks.flatgrass = $true
    Send "changelevel $CustomMap"
    Wait-Linked $CustomMap
    $checks.customMap = $true
    Send 'changelevel gm_construct'
    Wait-Linked 'gm_construct'
    $checks.returnToConstruct = $true
    $worldRoot = $configuration.worlds.Replace('/', '\')
    $managed = Get-CimInstance Win32_Process -Filter "name='java.exe'" | Where-Object { $_.CommandLine.Replace('/', '\').Contains($worldRoot) }
    $checks.singleClient = @($managed).Count -eq 1
    Send 'garrycraft_disable'
    Wait-Until 'final save and exit' { (Status).state -eq 'off' }
    $checks.noOrphan = -not (Get-CimInstance Win32_Process -Filter "name='java.exe'" | Where-Object { $_.CommandLine.Replace('/', '\').Contains($worldRoot) })
    $checks.optionRetainedAcrossMaps = ([IO.File]::ReadAllText($optionsPath) -match '(?m)^maxFps:180\r?$')
    Copy-Item -LiteralPath $optionsPath -Destination "$artifacts/options-after.txt"
    Copy-Item -LiteralPath "$artifacts/options-before.txt" -Destination $optionsPath -Force
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; samples=$samples; addon='crossbowboltgun'; customMap=$CustomMap} |
        ConvertTo-Json -Depth 8 | Set-Content "$artifacts/startup-result.json"
    if (-not $passed) { throw 'Startup checks failed. Read startup-result.json.' }
    Get-Content "$artifacts/startup-result.json"
} catch {
    @{passed=$false; checks=$checks; samples=$samples; error=$_.Exception.Message} |
        ConvertTo-Json -Depth 8 | Set-Content "$artifacts/startup-result.json"
    throw
}
