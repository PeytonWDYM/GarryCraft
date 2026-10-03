param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = Join-Path $LabPath 'garrysmod/data'
$output = Join-Path $RunRoot 'artifacts/directional'
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/directional-shadows.lua" "$data/directional-shadows.lua"
& "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'gamemode creative'
try {
& "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'fill 44 2 -10 44 6 -10 minecraft:oak_planks'
& "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'item replace entity @s hotbar.0 with minecraft:air'
& "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'tp @s 46 2.5 -8'
Start-Sleep -Seconds 2
Remove-Item -LiteralPath "$data/garrycraft-directional-shadows.json" -ErrorAction SilentlyContinue
& "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command "lua_run_cl RunString(file.Read('directional-shadows.lua','DATA'))"
$deadline = [DateTime]::UtcNow.AddSeconds(30)
while (-not (Test-Path -LiteralPath "$data/garrycraft-directional-shadows.json")) {
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Directional shadow captures did not complete.' }
    Start-Sleep -Milliseconds 200
}
Copy-Item "$data/garrycraft-directional-shadows.json" $output
Copy-Item "$data/garrycraft-directional/*.png" $output
} finally {
& "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'lua_run_cl if GarryCraft.DirectionalShadowTest then GarryCraft.DirectionalShadowTest.Finish(false) end'
& "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'fill 44 2 -10 44 6 -10 minecraft:air'
}
$run = Get-Content "$output/garrycraft-directional-shadows.json" -Raw | ConvertFrom-Json
$masks = @{}
$counts = @{}
foreach ($name in @('fixed','rotate','walk')) {
    $off, $on = $run.samples."$name-off", $run.samples."$name-on"
    if ($off.view -ne $on.view -or $off.angles -ne $on.angles) { throw 'Sun pair camera poses differ.' }
    $mask = @()
    for ($index = 0; $index -lt $off.pixels.Count; $index++) {
        $mask += $(if ($off.pixels[$index] -lt 0 -or $on.pixels[$index] -lt 0) { -1 }
            elseif ($off.pixels[$index] -gt 10 -and
                ($off.pixels[$index] - $on.pixels[$index]) / $off.pixels[$index] -gt .015) { 1 } else { 0 })
    }
    $masks[$name] = $mask
    $counts[$name] = @($mask | Where-Object { $_ -eq 1 }).Count
}
$comparisons = @{}
$oracle = @{}
foreach ($name in @('fixed','rotate','walk')) {
    $hit = 0; $extra = 0; $missing = 0
    for ($index = 0; $index -lt $masks[$name].Count; $index++) {
        if ($masks[$name][$index] -lt 0) { continue }
        $expected = $run.points[$index].expected
        if ($masks[$name][$index] -eq 1 -and $expected) { $hit++ }
        elseif ($masks[$name][$index] -eq 1) { $extra++ }
        elseif ($expected) { $missing++ }
    }
    $oracle[$name] = @{precision = $(if ($hit+$extra) { $hit/($hit+$extra) } else { 0 });
        recall = $(if ($hit+$missing) { $hit/($hit+$missing) } else { 0 })}
}
foreach ($name in @('rotate','walk')) {
    $common = 0; $same = 0
    for ($index = 0; $index -lt $masks.fixed.Count; $index++) {
        if ($masks.fixed[$index] -lt 0 -or $masks[$name][$index] -lt 0) { continue }
        $common++
        if ($masks.fixed[$index] -eq $masks[$name][$index]) { $same++ }
    }
    $comparisons[$name] = @{common = $common; agreement = $(if ($common) { $same / $common } else { 0 })}
}
$checks = [ordered]@{completed = $run.completed; visibleShadow = $counts.fixed -gt 20;
    rotationStable = $comparisons.rotate.common -gt 200 -and $comparisons.rotate.agreement -gt .95;
    walkingStable = $comparisons.walk.common -gt 200 -and $comparisons.walk.agreement -gt .95;
    productionOpacity = $run.samples.'fixed-on'.sun.brightness -eq .35}
foreach ($name in @('fixed','rotate','walk')) {
    $checks["${name}Precision"] = $oracle[$name].precision -gt .9
    $checks["${name}Recall"] = $oracle[$name].recall -gt .95
}
@{checks = $checks; counts = $counts; comparisons = $comparisons; oracle = $oracle} | ConvertTo-Json -Depth 4 | Set-Content "$output/result.json"
$checks
if ($checks.Values -contains $false) { throw 'Read the fixed-world-point pixels and paired sun PNGs.' }
