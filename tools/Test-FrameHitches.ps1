param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$output = "$RunRoot/artifacts/frame-hitches"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/frame-hitches.lua" "$LabPath/garrysmod/data/garrycraft-frame-hitches.lua"
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $command }
function Minecraft($command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $command }
Send 'sv_cheats 1'
Minecraft 'gamemode creative'
Minecraft 'tp @s 38 4 8'
Minecraft 'fill 32 2 0 47 2 15 minecraft:stone'
Start-Sleep -Seconds 5
Send "lua_run_cl RunString(file.Read('garrycraft-frame-hitches.lua','DATA'))"
Start-Sleep -Seconds 8
try {
    Send "lua_run_cl GarryCraft.FrameHitchTest.Mark('edits')"
    for ($index = 0; $index -lt 12; $index++) {
        $block = if ($index % 2 -eq 0) { 'minecraft:stone' } else { 'minecraft:air' }
        Minecraft "setblock 38 3 3 $block"
    }
    Send "lua_run_cl GarryCraft.FrameHitchTest.Mark('lighting')"
    Minecraft 'setblock 38 3 3 minecraft:torch'
    Start-Sleep -Seconds 5
    Minecraft 'setblock 38 3 3 minecraft:air'
    Start-Sleep -Seconds 5
} finally {
    Send 'lua_run_cl GarryCraft.FrameHitchTest.Finish()'
    Minecraft 'fill 32 2 0 47 3 15 minecraft:air'
}
Copy-Item "$LabPath/garrysmod/data/garrycraft-frame-hitches.json" $output
$trace = Get-Content "$output/garrycraft-frame-hitches.json" -Raw | ConvertFrom-Json
$phases = [ordered]@{}
foreach ($phase in 'idle', 'edits', 'lighting') {
    $values = @($trace.frames | Where-Object phase -eq $phase | ForEach-Object ms | Sort-Object)
    if ($values.Count -lt 100) { throw "Insufficient frames: $phase" }
    $phases[$phase] = @{count=$values.Count; p50=$values[[Math]::Ceiling($values.Count*.5)-1];
        p99=$values[[Math]::Ceiling($values.Count*.99)-1]; maximum=$values[-1];
        over16ms=@($values | Where-Object {$_ -gt 16.667}).Count}
}
@{completed=$trace.completed; phases=$phases; blocks=$trace.blocks; meshes=$trace.meshes} |
    ConvertTo-Json -Depth 12 | Set-Content "$output/result.json"
Get-Content "$output/result.json"
if (-not $trace.completed) { throw 'Bridge stopped during the hitch scenario.' }
