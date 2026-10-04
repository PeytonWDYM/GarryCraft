param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot, [ValidateRange(1,5)][int]$Cycles = 3)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$lab/garrysmod/data"
$output = "$RunRoot/artifacts/shutdown"
New-Item -ItemType Directory -Path $output -Force | Out-Null
$results = @()
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $command }
# Failure: Disable swaps a partial host packet into an active combat tick, or Java exits before saving.
for ($cycle = 1; $cycle -le $Cycles; $cycle++) {
    Send 'garrycraft_enabled 1'
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        Start-Sleep -Milliseconds 500
        $status = Get-Content "$data/garrycraft-runtime-status.json" -Raw | ConvertFrom-Json
        $started = $status.state -eq 'ready' -and $status.hostPid -eq $GamePid -and
            $status.javaPid -notin @($results.javaPid) -and [bool](Get-Process -Id $status.javaPid -ErrorAction SilentlyContinue)
    } while (-not $started -and [DateTime]::UtcNow -lt $deadline)
    if (-not $started) { throw 'Minecraft did not become ready for the shutdown test.' }
    Start-Sleep -Seconds 2
    $beforeReports = @(Get-ChildItem "$RunRoot/minecraft/crash-reports" -File -ErrorAction SilentlyContinue).Count
    Send 'garrycraft_enabled 0'
    $deadline = [DateTime]::UtcNow.AddSeconds(40)
    do {
        Start-Sleep -Milliseconds 500
        $stopped = -not (Get-Process -Id $status.javaPid -ErrorAction SilentlyContinue)
    } while (-not $stopped -and [DateTime]::UtcNow -lt $deadline)
    $stdout = Get-Content "$RunRoot/minecraft-stdout.log" -Raw
    $stderr = Get-Content "$RunRoot/minecraft-stderr.log" -Raw
    Copy-Item "$RunRoot/minecraft-stdout.log" "$output/cycle-$cycle-stdout.log" -Force
    Copy-Item "$RunRoot/minecraft-stderr.log" "$output/cycle-$cycle-stderr.log" -Force
    $afterReports = @(Get-ChildItem "$RunRoot/minecraft/crash-reports" -File -ErrorAction SilentlyContinue).Count
    $checks = @{freshClient=$started;exited=$stopped;saveRequested=$stdout.Contains('launcher requested Minecraft shutdown');
        worldSaved=$stdout.Contains('Saving worlds');noCrash=$afterReports -eq $beforeReports -and
        -not $stdout.Contains('Game crashed!') -and -not $stderr.Contains('SourceMobs.tick')}
    $results += @{cycle=$cycle;javaPid=$status.javaPid;checks=$checks;passed=-not($checks.Values -contains $false)}
}
$report = @{passed=-not($results.passed -contains $false);cycles=$results}
$report | ConvertTo-Json -Depth 6 | Set-Content "$output/result.json"
$report | ConvertTo-Json -Depth 6
if (-not $report.passed) { throw 'Read the Source shutdown traces.' }
