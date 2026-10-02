param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$artifacts = "$RunRoot/artifacts"
$resultsPath = "$artifacts/results.json"
if (Test-Path -LiteralPath $resultsPath) { Remove-Item -LiteralPath $resultsPath }
$originPath = "$LabPath/garrysmod/data/garrycraft-physics-origin.json"
if (Test-Path -LiteralPath $originPath) { Remove-Item -LiteralPath $originPath }
& "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command 'garrycraft_test'
& "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command "lua_run file.Write('garrycraft-physics-origin.json',util.TableToJSON(GarryCraft.ToMinecraft(GarryCraft.LabOrigin)))"
$deadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath $originPath) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
Copy-Item -LiteralPath $originPath -Destination $artifacts
$origin = Get-Content -LiteralPath $originPath -Raw | ConvertFrom-Json
$deadline = [DateTime]::UtcNow.AddMinutes(4)
while (-not (Test-Path -LiteralPath $resultsPath) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 500
}
if (-not (Test-Path -LiteralPath $resultsPath)) { throw 'The physics replay did not finish.' }
$results = Get-Content -LiteralPath $resultsPath -Raw | ConvertFrom-Json
# The last case leaves both players falling. Completion must return them to the safe Source floor.
# A delayed death, stale velocity, lost ground contact, or a disconnected bridge must fail this check.
$samples = @()
for ($i = 0; $i -lt 16; $i++) {
    Start-Sleep -Milliseconds 500
    $samples += & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin"
}
$checks = [ordered]@{
    vanillaComparisons = $results.Count -eq 15 -and -not ($results | Where-Object { -not $_.passed })
    aliveAfterCompletion = -not ($samples | Where-Object { $_.deaths -ne 0 -or $_.health -le 0 })
    safeOrigin = -not ($samples | Where-Object { [Math]::Abs($_.x - $origin[0]) -gt .01 -or [Math]::Abs($_.y - $origin[1]) -gt .01 -or [Math]::Abs($_.z - $origin[2]) -gt .01 })
    settled = -not ($samples | Where-Object { -not $_.grounded -or $_.gliding -or [Math]::Abs($_.vy) -gt .1 })
    connected = -not ($samples | Where-Object { -not $_.linked -or -not $_.geometryReady })
}
$report = @{passed=-not ($checks.Values -contains $false); checks=$checks; origin=$origin; samples=$samples; results=$results}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$artifacts/physics-cleanup-result.json" -Encoding utf8NoBOM
$checks | ConvertTo-Json
if (-not $report.passed) { throw 'Physics cleanup failed. Read physics-cleanup-result.json and the paired tick traces.' }
