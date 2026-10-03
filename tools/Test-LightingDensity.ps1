param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$output = "$RunRoot/artifacts/density"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/lighting-density.lua" "$data/lighting-density.lua"
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Minecraft($Command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
Minecraft 'tp @s 37.5 2.5 0.5'
Send "lua_run_cl RunString(file.Read('lighting-density.lua','DATA'))"
Start-Sleep -Seconds 3
try {
    Send "lua_run_cl GarryCraft.LightingDensityTest.Mark('add')"
    Minecraft 'fill 34 2 -5 41 2 -1 minecraft:torch'
    Start-Sleep -Seconds 5
    Send "lua_run_cl GarryCraft.LightingDensityTest.Mark('steady')"
    Start-Sleep -Seconds 10
} finally {
    Send "lua_run_cl GarryCraft.LightingDensityTest.Mark('remove')"
    Minecraft 'fill 34 2 -5 41 2 -1 minecraft:air'
    Start-Sleep -Seconds 3
    Send 'lua_run_cl GarryCraft.LightingDensityTest.Finish()'
}
Start-Sleep -Milliseconds 500
Copy-Item "$data/garrycraft-lighting-density.json" $output
$run = Get-Content "$output/garrycraft-lighting-density.json" -Raw | ConvertFrom-Json
$steady = @($run.samples | Where-Object phase -eq 'steady')
function Percentile($Values, $Percent) {
    $sorted = @($Values | Sort-Object)
    $sorted[[Math]::Floor(($sorted.Count-1)*$Percent)]
}
$baseline = @($run.samples | Where-Object phase -eq 'baseline' | Select-Object -Skip 30)
$baseP99 = Percentile $baseline.frameMs .99
$steadyP99 = Percentile $steady.frameMs .99
$maximum = ($run.samples | Select-Object -Skip 30 | ForEach-Object frameMs | Measure-Object -Maximum).Maximum
$checks = [ordered]@{completed = $run.completed; exportedForty = ($steady.lights | Measure-Object -Minimum).Minimum -ge 40;
    completedField = @($steady | Where-Object {$_.voxels.sections -gt 0}).Count -gt 0;
    baselineResponsive = $baseP99 -lt 33.34;
    steadyResponsive = $steadyP99 -lt [Math]::Max(16.67, $baseP99 * 1.2);
    transitionsResponsive = $maximum -lt 50;
    reusedLightingGeometry = $run.samples[-1].reused -gt $run.samples[0].reused}
$result = @{checks = $checks; baselineP99 = $baseP99; frameP99 = $steadyP99; maxFrame = $maximum;
    maxLightmapMs = ($run.samples.voxels.lightmaps.update_ms | Measure-Object -Maximum).Maximum;
    maxLightmapUploadMs = ($run.samples.voxels.lightmaps.upload_ms | Measure-Object -Maximum).Maximum;
    voxelSections = ($steady.voxels.sections | Measure-Object -Maximum).Maximum}
$result | ConvertTo-Json -Depth 4 | Set-Content "$output/result.json"
$result
if ($checks.Values -contains $false) { throw 'Read the density trace.' }
