param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts"
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Snapshot($Name) {
    $filename = "garrycraft-lighting-cleanup-$Name.json"
    if (Test-Path "$data/$filename") { Remove-Item -LiteralPath "$data/$filename" }
    Send "lua_run_cl file.Write('$filename',util.TableToJSON({shadows=GetConVar('garrycraft_source_shadows'):GetString(),inactive=not LocalPlayer():GetNWBool('GarryCraft'),noShadow=LocalPlayer():IsEffectActive(EF_NOSHADOW),native=garrycraft_bridge.shadow_stats()}))"
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path "$data/$filename") -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Copy-Item -LiteralPath "$data/$filename" -Destination $artifacts
    Get-Content "$artifacts/$filename" -Raw | ConvertFrom-Json
}
# Cancel during the phase that disables shadows. Both the archived setting and native player flag must recover.
Send 'garrycraft_stop'
Start-Sleep -Seconds 1
$before = Snapshot 'before'
try {
    Send 'garrycraft_source_shadows 1'
    Send 'garrycraft_test lighting'
    $deadline = [DateTime]::UtcNow.AddSeconds(65)
    do {
        $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin"
        if ($state.lightingTestPhase -eq 'shadowOff') { break }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($state.lightingTestPhase -ne 'shadowOff') { throw 'The lighting cancellation phase did not start.' }
    Start-Sleep -Seconds 1
    $during = Snapshot 'during'
    Send 'garrycraft_stop'
    Start-Sleep -Seconds 1
    $after = Snapshot 'after'
    $checks = [ordered]@{phaseReached=$during.shadows -eq '0'; archivedSettingRestored=$after.shadows -eq '1';
        nativeShadowSuppressed=$during.noShadow; nativeShadowRestored=$after.noShadow -eq $before.noShadow;
        stopped=$after.inactive; unregistered=$after.native.registered -eq 0}
    $result = @{passed=-not ($checks.Values -contains $false); checks=$checks; before=$before; during=$during; after=$after}
    $result | ConvertTo-Json -Depth 5 | Set-Content "$artifacts/lighting-cleanup-result.json" -Encoding utf8NoBOM
    $result | ConvertTo-Json -Depth 5
    if (-not $result.passed) { throw 'Lighting cancellation failed. Read lighting-cleanup-result.json.' }
} finally {
    Send "garrycraft_source_shadows $($before.shadows)"
}
