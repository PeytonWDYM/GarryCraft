param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot, [switch]$Baseline)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$output = "$RunRoot/artifacts/receivers"
New-Item -ItemType Directory -Path $output -Force | Out-Null
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Minecraft($Command) {
    & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command
}
function Capture($Name) {
    Remove-Item -LiteralPath "$data/garrycraft-receivers/$Name.json" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Send "lua_run_cl GarryCraft.ReceiverTest.Capture('$Name')"
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath "$data/garrycraft-receivers/$Name.json")) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "Receiver capture timed out: $Name" }
        Start-Sleep -Milliseconds 100
    }
    Copy-Item -LiteralPath "$data/garrycraft-receivers/$Name.json", "$data/garrycraft-receivers/$Name.png" -Destination $output
}
Copy-Item "$PSScriptRoot/../tests/lighting-receivers.lua" "$data/lighting-receivers.lua"
Send 'sv_cheats 1'
Minecraft 'gamemode creative'
Minecraft 'item replace entity @s hotbar.0 with minecraft:air'
Minecraft 'fill 34 1 -3 40 6 3 minecraft:oak_planks hollow'
Minecraft 'tp @s 37.5 2.5 0.5'
Send "lua_run local prop=ents.Create('prop_physics') prop:SetModel('models/props_junk/wood_crate001a.mdl') prop:SetPos(GarryCraft.ToSource(35.5,2.75,1.5)) prop:Spawn() prop:GetPhysicsObject():EnableMotion(false) prop:SetName('garrycraft-receivers-crate')"
Send "lua_run_cl RunString(file.Read('lighting-receivers.lua','DATA')) GarryCraft.ReceiverTest.View(GarryCraft.ToSource(37.5,3.62,.5),Angle(15,-180,0))"
try {
    Capture 'sealed'
    Minecraft 'setblock 41 2 0 minecraft:torch'
    Capture 'outside-torch'
    Minecraft 'setblock 41 2 0 minecraft:glowstone'
    Capture 'outside-solid-emitter'
    Minecraft 'setblock 41 2 0 minecraft:torch'
    Minecraft 'setblock 36 2 0 minecraft:torch'
    Capture 'inside-torch'
    Send 'garrycraft_sun_shadows 0'
    Capture 'inside-torch-sun-off'
    Send 'garrycraft_sun_shadows 1'
    Minecraft 'setblock 36 2 0 minecraft:air'
    Minecraft 'fill 34 6 -3 40 6 3 minecraft:air'
    Capture 'open-roof'
    Minecraft 'fill 34 6 -3 40 6 3 minecraft:glass'
    Capture 'clear-glass-roof'
    Minecraft 'fill 34 6 -3 40 6 3 minecraft:tinted_glass'
    Capture 'tinted-glass-roof'
    Minecraft 'fill 34 6 -3 40 6 3 minecraft:water'
    Capture 'water-roof'
    Minecraft 'fill 33 1 -4 41 7 4 minecraft:air replace minecraft:water'
    Minecraft 'setblock 41 2 0 minecraft:air'
    Minecraft 'fill 34 1 -3 40 6 3 minecraft:oak_planks hollow'
    Minecraft 'fill 40 2 -2 40 5 2 minecraft:air'
    Capture 'open-front'
    Minecraft 'fill 34 1 -3 40 8 3 minecraft:oak_planks hollow'
    Minecraft 'fill 34 3 -3 34 7 1 minecraft:glass'
    Capture 'sun-facing-window'
    Send 'garrycraft_sun_shadows 0'
    Capture 'sun-facing-window-off'
    Send 'garrycraft_sun_shadows 1'
    Minecraft 'fill 34 3 -3 34 7 1 minecraft:oak_planks'
    Minecraft 'fill 40 3 -3 40 7 1 minecraft:glass'
    Capture 'opposite-window'
    Send 'garrycraft_sun_shadows 0'
    Capture 'opposite-window-off'
    Send 'garrycraft_sun_shadows 1'
    Minecraft 'fill 34 1 -3 40 8 3 minecraft:air'
    Minecraft 'fill 34 1 -3 40 6 3 minecraft:oak_planks hollow'
    Minecraft 'fill 34 6 -3 40 6 3 minecraft:air'
    Send "lua_run_cl GarryCraft.ReceiverTest.View(GarryCraft.ToSource(37.5,3.62,.5),Angle(15,-155,0))"
    Capture 'rotate'
    Send "lua_run_cl GarryCraft.ReceiverTest.View(GarryCraft.ToSource(38.5,3.62,.5),Angle(15,-180,0))"
    Capture 'walk'
} finally {
    Send "lua_run_cl GarryCraft.ReceiverTest.Finish()"
    Send "lua_run for _,p in ipairs(ents.FindByName('garrycraft-receivers-crate')) do p:Remove() end"
    Minecraft 'fill 33 1 -4 41 9 4 minecraft:air'
}
$rows = @{}
foreach ($name in @('sealed','outside-torch','outside-solid-emitter','inside-torch','inside-torch-sun-off','open-roof',
    'clear-glass-roof','tinted-glass-roof','water-roof','open-front','rotate','walk',
    'sun-facing-window','sun-facing-window-off','opposite-window','opposite-window-off')) {
    $rows[$name] = Get-Content -LiteralPath "$output/$name.json" -Raw | ConvertFrom-Json
}
function Luminance($Name) {
    ($rows[$Name].pixels | ForEach-Object { .2126 * $_[0] + .7152 * $_[1] + .0722 * $_[2] } | Measure-Object -Average).Average
}
$checks = [ordered]@{
    sealedPixels = (Luminance 'sealed') -lt (Luminance 'open-roof') - 10
    insideTorchPixels = (Luminance 'inside-torch') -gt (Luminance 'sealed') + 5
    fixedSunRotation = $rows['open-roof'].sun.mode -eq 'directional-irradiance' -and $rows['open-roof'].sun.direction -eq $rows['rotate'].sun.direction
    fixedSunWalking = $rows['open-roof'].sun.mode -eq 'directional-irradiance' -and $rows['open-roof'].sun.direction -eq $rows['walk'].sun.direction
    productionBrightness = $rows['open-roof'].sun.brightness -eq .35
    nativeFloorVisible = $rows['sealed'].receivers.floor.nativeSurface
    openFrontTransport = $rows['open-front'].transport.sky -ge 10
    openFrontPixels = $rows['open-front'].receivers.wall.luminance -gt $rows['sealed'].receivers.wall.luminance + 10
    clearGlassTransport = $rows['clear-glass-roof'].transport.sky -eq $rows['open-roof'].transport.sky
    tintedGlassTransport = $rows['tinted-glass-roof'].transport.sky -eq $rows['sealed'].transport.sky
    waterTransport = $rows['water-roof'].transport.sky -lt $rows['clear-glass-roof'].transport.sky -and
        $rows['water-roof'].transport.sky -gt $rows['tinted-glass-roof'].transport.sky
    clearGlassPixels = $rows['clear-glass-roof'].receivers.wall.luminance -gt $rows['tinted-glass-roof'].receivers.wall.luminance + 10
    angledSunThroughWindow = $rows['sun-facing-window'].receivers.floor.sunTransmission -gt .99
    oppositeWindowBlocksSun = $rows['opposite-window'].receivers.floor.sunTransmission -lt .01
    windowReceivesDirectSun = $rows['sun-facing-window'].receivers.floor.luminance -gt $rows['sun-facing-window-off'].receivers.floor.luminance + 2
    oppositeWindowStaysShaded = $rows['opposite-window'].receivers.floor.luminance -lt $rows['opposite-window-off'].receivers.floor.luminance - 2
}
foreach ($receiver in @('crate','floor','wall')) {
    $dark = $rows['sealed'].receivers.$receiver.luminance
    $lit = $rows['inside-torch'].receivers.$receiver.luminance
    $open = $rows['open-roof'].receivers.$receiver.luminance
    $outside = $rows['outside-torch'].receivers.$receiver.luminance
    $checks["${receiver}Darkens"] = $dark -lt $open - 5
    $checks["${receiver}TorchBlocked"] = [Math]::Abs($dark - $outside) -lt 2
    $checks["${receiver}SolidEmitterBlocked"] = [Math]::Abs($dark - $rows['outside-solid-emitter'].receivers.$receiver.luminance) -lt 3
    $checks["${receiver}TorchLights"] = $lit -gt $dark + 5
    $checks["${receiver}TorchIndependentOfSun"] = [Math]::Abs($lit - $rows['inside-torch-sun-off'].receivers.$receiver.luminance) -lt 2
}
$checks | ConvertTo-Json | Set-Content -LiteralPath "$output/checks.json"
$checks
if (-not $Baseline -and $checks.Values -contains $false) { throw 'Receiver scenario failed. Inspect the PNGs and JSON.' }
