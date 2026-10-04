param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$lab/garrysmod/data"
$output = "$RunRoot/artifacts/rapid-edits"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/../tests/rapid-edits.lua" -Destination "$data/garrycraft-rapid-edits.lua"
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $Command }
function Minecraft($Command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $Command }
Send 'sv_cheats 1'
Minecraft 'gamemode creative'
Minecraft 'item replace entity @s hotbar.1 with minecraft:oak_log'
Minecraft 'tp @s -47 -6 52'
Minecraft 'fill -50 -6 46 -46 -1 51 air'
Minecraft 'fill -49 -6 47 -48 -6 48 minecraft:oak_log'
Start-Sleep -Seconds 3
Remove-Item -LiteralPath "$data/garrycraft-rapid-edits.json", "$data/garrycraft-rapid-edits.png" -ErrorAction SilentlyContinue
Send "lua_run_cl RunString(file.Read('garrycraft-rapid-edits.lua','DATA')) GarryCraft.RapidEditTest.Begin(-49,-6,47)"
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not (Test-Path -LiteralPath "$data/garrycraft-rapid-edits.json")) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Rapid edit capture timed out.' }
        Start-Sleep -Milliseconds 200
    }
    Copy-Item -LiteralPath "$data/garrycraft-rapid-edits.json", "$data/garrycraft-rapid-edits.png" -Destination $output
} finally {
    Send 'lua_run_cl GarryCraft.RapidEditTest.Stop()'
}
$run = Get-Content -Raw -LiteralPath "$output/garrycraft-rapid-edits.json" | ConvertFrom-Json
$settled = @($run.frames | Where-Object { $_.time -ge 25 })
$checks = [ordered]@{
    recorded = $run.frames.Count -gt 100
    placed = ($run.frames.cells | Measure-Object -Maximum).Maximum -gt 4
    mined = @($run.frames | Where-Object { $_.time -gt 2 -and $_.time -lt 24 -and $_.cells -eq 4 }).Count -gt 5
    settled = $settled.Count -gt 10
    noMissingFaces = @($settled | Where-Object { $_.expectedFaces -eq 0 -or $_.vertices -ne $_.expectedFaces * 6 }).Count -eq 0
}
# Independent fixture truth: 55 cubes minus an eight-cube opening expose 108 faces.
# This crosses both section boundaries and catches a stale mesh/voxel pair.
Minecraft 'fill -50 -6 46 -46 -1 51 air'
Minecraft 'fill -49 -6 47 -47 -2 49 minecraft:jungle_log'
Minecraft 'fill -48 -6 50 -47 -2 50 minecraft:jungle_log'
Minecraft 'fill -48 -4 48 -47 -3 49 air'
Start-Sleep -Seconds 3
Remove-Item -LiteralPath "$data/garrycraft-rapid-edits-truth.json" -ErrorAction SilentlyContinue
Send "lua_run_cl file.Write('garrycraft-rapid-edits-truth.json',util.TableToJSON(GarryCraft.BlockRenderReport(),true))"
$deadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath "$data/garrycraft-rapid-edits-truth.json")) {
    if ([DateTime]::UtcNow -gt $deadline) { throw 'The known opening probe did not return a report.' }
    Start-Sleep -Milliseconds 100
}
Copy-Item -LiteralPath "$data/garrycraft-rapid-edits-truth.json" -Destination $output
$truth = Get-Content -Raw -LiteralPath "$output/garrycraft-rapid-edits-truth.json" | ConvertFrom-Json
$checks.knownOpening = $truth.vertices -eq 108 * 6
$report = @{checks=$checks;passed=-not($checks.Values -contains $false)}
$report | ConvertTo-Json | Set-Content -LiteralPath "$output/result.json"
$report | ConvertTo-Json
if (-not $report.passed) { throw 'Read the rapid edit trace and screenshot.' }
