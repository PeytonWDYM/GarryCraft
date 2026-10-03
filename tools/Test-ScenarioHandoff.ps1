param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$checks = [ordered]@{}
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function State { & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin" }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Collect-Lighting($Name, $Request) {
    Wait-Until "$Name lighting completion" {
        if (-not (Test-Path -LiteralPath "$RunRoot/artifacts/lighting-minecraft.json")) { return $false }
        $report = Get-Content "$RunRoot/artifacts/lighting-minecraft.json" -Raw | ConvertFrom-Json
        $report.request -eq $Request -and $report.completed
    }
    Start-Sleep -Seconds 1
    $destination = "$RunRoot/handoff/$Name"
    New-Item -ItemType Directory -Path "$destination/artifacts" -Force | Out-Null
    Copy-Item -LiteralPath "$RunRoot/artifacts/lighting-minecraft.json" -Destination "$destination/artifacts"
    & "$PSScriptRoot/Collect-Lighting.ps1" -RunRoot $destination -LabPath $LabPath
    Wait-Until "$Name game mode restoration" { (State).gameMode -eq $script:initialMode }
}
$initialMode = (State).gameMode
# Fail if a replaced replay keeps sampling, moves the replacement fixture, or restores a temporary game mode.
Send 'garrycraft_test'
Wait-Until 'active vanilla walk' { $state = State; $state.fixture -eq 'walk' -and $state.reference -and [Math]::Abs($state.z - 128.5) -gt .1 }
$previous = (State).lightingTestRequest
Send 'garrycraft_test lighting'
Wait-Until 'lighting replacing physics' { $state = State; $state.lightingTestRequest -ne $previous -and $state.lightingTestPhase -eq 'floor' }
$request = (State).lightingTestRequest
$checks.physicsCanceled = (State).fixture -eq '' -and -not (State).reference
Collect-Lighting 'physics-to-lighting' $request
$checks.physicsToLighting = $true

Send 'garrycraft_test lighting'
Wait-Until 'second lighting setup' { $state = State; $state.lightingTestRequest -ne $request -and $state.lightingTestPhase -eq 'floor' }
$lightingRequest = (State).lightingTestRequest
Send 'garrycraft_test damage'
Wait-Until 'replacement damage completion' {
    $path = "$RunRoot/artifacts/damage-minecraft.json"
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $report = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $report.request -eq (State).damageTestRequest -and $report.hits.Count -eq 4
}
& "$PSScriptRoot/Collect-Damage.ps1" -RunRoot $RunRoot -LabPath $LabPath
$canceled = Get-Content "$RunRoot/artifacts/lighting-minecraft.json" -Raw | ConvertFrom-Json
$checks.lightingCanceled = $canceled.request -eq $lightingRequest -and -not $canceled.completed
Wait-Until 'damage restored original game mode' { (State).gameMode -eq $initialMode }
$checks.lightingToDamage = $true

$previous = (State).damageTestRequest
Send 'garrycraft_test damage'
Wait-Until 'active damage setup' { $state = State; $state.damageTestRequest -ne $previous -and $state.gameMode -eq 'survival' }
$previous = (State).lightingTestRequest
Send 'garrycraft_test lighting'
Wait-Until 'lighting replacing damage' { $state = State; $state.lightingTestRequest -ne $previous -and $state.lightingTestPhase -eq 'floor' }
Collect-Lighting 'damage-to-lighting' (State).lightingTestRequest
$checks.damageToLighting = $true
$report = @{passed=-not ($checks.Values -contains $false); checks=$checks; initialMode=$initialMode; finalState=(State)}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$RunRoot/artifacts/scenario-handoff-result.json" -Encoding utf8NoBOM
$checks | ConvertTo-Json
if (-not $report.passed) { throw 'Scenario handoff failed. Read the paired traces.' }
