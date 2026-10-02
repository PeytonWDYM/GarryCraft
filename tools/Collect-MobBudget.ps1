param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/Collect-Lab.ps1" -RunRoot $RunRoot -LabPath $LabPath
$destination = Join-Path $RunRoot 'artifacts'
foreach ($name in @('mob-budget', 'mob-cleanup')) {
    Copy-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-$name.json" -Destination $destination
}
$budget = Get-Content -Raw "$destination/garrycraft-mob-budget.json" | ConvertFrom-Json
$cleanup = Get-Content -Raw "$destination/garrycraft-mob-cleanup.json" | ConvertFrom-Json
$parity = Get-Content -Raw "$destination/parity-minecraft.json" | ConvertFrom-Json
if ($budget.request -ne $parity.request -or $cleanup.request -ne $budget.request -or -not $budget.passed -or
    $cleanup.bullseyes -ne 0 -or $cleanup.testNpcs -ne 0) {
    throw 'Mob budget or cleanup failed. Read the paired artifacts.'
}
$budget | Select-Object request, candidatePairs, maximumPairs, maximumTraces, targetedNpcs, maximumTargeted, scanCompleted, remainingNpcs, passed
$cleanup
