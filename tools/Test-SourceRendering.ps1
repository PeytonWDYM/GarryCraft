param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$lab/garrysmod/data"
$output = "$RunRoot/artifacts/source-rendering"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/../tests/source-rendering.lua" -Destination "$data/garrycraft-source-rendering.lua"
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $command }
function Minecraft($command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $command }
function Capture($label) {
    Start-Sleep -Seconds 2
    $record = "$data/garrycraft-source-rendering/$label.json"
    Remove-Item -LiteralPath $record -ErrorAction SilentlyContinue
    Send "lua_run_cl GarryCraft.SourceRenderingTest.Capture('$label')"
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not ((Test-Path -LiteralPath $record) -and (Test-Path -LiteralPath "$data/garrycraft-source-rendering/$label.png"))) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "Source rendering capture timed out: $label" }
        Start-Sleep -Milliseconds 100
    }
    Copy-Item -Path "$data/garrycraft-source-rendering/$label.*" -Destination $output -Force
    Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
}
Send 'sv_cheats 1'
Minecraft 'gamemode creative'
Minecraft 'tp @s 38 4 8'
Minecraft 'fill 32 2 0 47 2 15 minecraft:stone'
Minecraft 'fill 36 3 0 39 4 0 minecraft:stone'
Minecraft 'setblock 42 3 2 minecraft:water[level=0]'
Send "lua_run_cl RunString(file.Read('garrycraft-source-rendering.lua','DATA'))"
try {
    $baseline = Capture 'baseline'
    Send 'lua_run_cl GarryCraft.SourceRenderingTest.Lamp(true)'
    $lit = Capture 'native-lamp'
    Send 'lua_run_cl GarryCraft.SourceRenderingTest.WaterLamp()'
    $waterLit = Capture 'water-lamp'
    Send 'lua_run_cl GarryCraft.SourceRenderingTest.Lamp(false)'
    Minecraft 'setblock 42 3 2 minecraft:air'
    $drained = Capture 'drained'
    Minecraft 'setblock 42 3 2 minecraft:water[level=0]'
    $refilled = Capture 'refilled'
} finally {
    Send 'lua_run_cl GarryCraft.SourceRenderingTest.Stop()'
    Minecraft 'fill 32 2 0 47 4 15 minecraft:air'
}
$checks = [ordered]@{
    sourceRenderer = $baseline.blocks.renderer -eq 'source'
    opaqueModels = $baseline.models.world -gt 0
    waterRendered = $baseline.water.Count -gt 0 -and $baseline.blocks.sourceModels.manualDraws -gt 0
    blockLitBySource = $lit.pixels.block.rgb[0] -gt $baseline.pixels.block.rgb[0] + 8
    propLitBySource = $lit.pixels.prop.rgb[0] -gt $baseline.pixels.prop.rgb[0] + 8
    waterLitBySource = $waterLit.pixels.water.rgb[0] -gt $baseline.pixels.water.rgb[0] + 5
    waterPixels = $baseline.pixels.water.rgb[2] -gt $baseline.pixels.water.rgb[0] + 20 -and
        [Math]::Abs($baseline.pixels.water.rgb[2] - $drained.pixels.water.rgb[2]) -gt 15
    waterDrained = $drained.water.Count -eq 0
    waterRefilled = $refilled.water.Count -gt 0
    flowingWater = $baseline.water.Count -gt 6
    nativeShadowCasts = $lit.native.castDraws -gt $baseline.native.castDraws
    validNativeDraws = $refilled.native.invalidMeshes -eq 0 -and $refilled.native.wrongThread -eq 0
}
$frames = @(@($baseline.frameTimes) + @($lit.frameTimes) + @($waterLit.frameTimes) + @($drained.frameTimes) + @($refilled.frameTimes) | Sort-Object)
$timing = @{count=$frames.Count;p99=$frames[[Math]::Ceiling($frames.Count*.99)-1];maximum=$frames[-1];
    over16ms=@($frames | Where-Object { $_ -gt 16.667 }).Count}
$checks.recordedFrames = $frames.Count -gt 100
$report = @{checks=$checks;passed=-not($checks.Values -contains $false);frames=$timing}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$output/result.json"
$report | ConvertTo-Json -Depth 8
if (-not $report.passed) { throw 'Read the Source rendering pixels, traces, and screenshots.' }
