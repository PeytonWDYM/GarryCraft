param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$output = "$RunRoot/artifacts/collision-edits"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/collision-edits.lua" "$lab/garrysmod/data/garrycraft-collision-edits.lua"
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $command }
function Minecraft($command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $command }
function Capture($label) {
    Start-Sleep -Seconds 3
    Send "lua_run GarryCraft.CollisionEditTest.Capture('$label')"
}
Send "lua_run RunString(file.Read('garrycraft-collision-edits.lua','DATA'))"
Minecraft 'fill 32 6 0 47 6 15 minecraft:stone'
try {
    Capture 'floor'
    Minecraft 'setblock 38 6 3 minecraft:air'
    Capture 'hole'
    Minecraft 'setblock 38 6 3 minecraft:stone'
    Capture 'replaced'
    Minecraft 'setblock 40 6 3 minecraft:stone_slab[type=bottom]'
    Minecraft 'setblock 42 6 3 minecraft:stone_stairs[facing=east,half=bottom,shape=straight]'
    Capture 'shapes'
    Minecraft 'setblock 44 7 3 minecraft:torch'
    Capture 'lit'
    Minecraft 'setblock 44 7 3 minecraft:air'
    Capture 'unlit'
} finally {
    Copy-Item "$lab/garrysmod/data/garrycraft-collision-edits.json" $output
    Minecraft 'fill 32 6 0 47 7 15 minecraft:air'
}
$trace = Get-Content "$output/garrycraft-collision-edits.json" -Raw | ConvertFrom-Json
$checks = [ordered]@{
    floor = $trace.floor.probes[0].hit -and [Math]::Abs($trace.floor.probes[0].y-7) -lt .01
    hole = -not $trace.hole.probes[0].hit
    replaced = $trace.replaced.probes[0].hit -and [Math]::Abs($trace.replaced.probes[0].y-7) -lt .01
    slab = [Math]::Abs($trace.shapes.probes[1].y-6.5) -lt .01
    stair = [Math]::Abs($trace.shapes.probes[2].y-6.5) -lt .01 -and [Math]::Abs($trace.shapes.probes[3].y-7) -lt .01
    lightingRetainsBodies = ($trace.shapes.bodies | ConvertTo-Json -Compress) -eq ($trace.lit.bodies | ConvertTo-Json -Compress) -and
        ($trace.lit.bodies | ConvertTo-Json -Compress) -eq ($trace.unlit.bodies | ConvertTo-Json -Compress)
    compactFloor = ($trace.floor.bodies.convexes | Measure-Object -Sum).Sum -eq 1
}
@{checks=$checks;passed=-not($checks.Values -contains $false)} | ConvertTo-Json | Set-Content "$output/result.json"
Get-Content "$output/result.json"
if ($checks.Values -contains $false) { throw 'Read the collision edit trace.' }
