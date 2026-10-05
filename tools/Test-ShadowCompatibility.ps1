param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][int]$GamePid,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new report directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$data = "$lab/garrysmod/data"
foreach ($name in 'source-shadow-path', 'shadow-compatibility', 'shadow-fallback') {
    Copy-Item -LiteralPath "$PSScriptRoot/../tests/$name.lua" -Destination "$data/garrycraft-$name.lua" -Force
}
function Send([string]$Command) {
    & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $lab -Command $Command
}
$checks = [ordered]@{}
try {
    foreach ($phase in 'first', 'reopen', 'late-first', 'late-reopen', 'early-first', 'early-reopen') {
        if ($phase -eq 'late-first') { Send "lua_run_cl require('garrycraft_shadow_test') garrycraft_shadow_test.hook_model()" }
        if ($phase -eq 'early-first') {
            Send 'lua_run_cl garrycraft_bridge.close() garrycraft_shadow_test.restore() garrycraft_bridge.close() garrycraft_shadow_test.hook_model()'
        }
        if ($phase -in 'reopen', 'late-reopen', 'early-reopen') {
            Remove-Item -LiteralPath "$data/garrycraft-shadow-closed.json" -ErrorAction SilentlyContinue
            Send "lua_run_cl garrycraft_bridge.close() file.Write('garrycraft-shadow-closed.json',util.TableToJSON(garrycraft_bridge.shadow_stats()))"
            $closeDeadline = [DateTime]::UtcNow.AddSeconds(15)
            while (-not (Test-Path -LiteralPath "$data/garrycraft-shadow-closed.json")) {
                if ([DateTime]::UtcNow -gt $closeDeadline) { throw 'Shadow close did not report.' }
                Start-Sleep -Milliseconds 250
            }
            Copy-Item -LiteralPath "$data/garrycraft-shadow-closed.json" -Destination "$RunRoot/$phase-closed.json"
            $closed = Get-Content "$RunRoot/$phase-closed.json" -Raw | ConvertFrom-Json
            $checks["$phase-closeMode"] = $closed.closeMode -eq $(if ($phase -eq 'late-reopen') { 'forwarding' } else { 'restored' })
        }
        $report = "$data/garrycraft-shadow-compatibility.json"
        Remove-Item -LiteralPath $report -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$data/garrycraft-source-shadow-cleanup.json" -ErrorAction SilentlyContinue
        Send "lua_run_cl RunString(file.Read('garrycraft-shadow-compatibility.lua','DATA'))"
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while (-not (Test-Path -LiteralPath $report)) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'The shadow compatibility probe did not report.' }
            Start-Sleep -Milliseconds 250
        }
        Copy-Item -LiteralPath $report -Destination "$RunRoot/$phase-compatibility.json"
        $compatibility = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        $checks["$phase-registration"] = $compatibility.registered -and $compatibility.native.installed
        if ($phase -in 'early-first', 'early-reopen') { $checks["$phase-chainedModel"] = $compatibility.native.chainedModel }
        if (-not $checks["$phase-registration"]) { throw "Shadow registration failed: $($compatibility.failure)" }
        while (-not (Test-Path -LiteralPath "$data/garrycraft-source-shadow-cleanup.json")) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'The native shadow capture did not complete.' }
            Start-Sleep -Milliseconds 250
        }
        $capture = Get-Content "$data/garrycraft-source-shadow-path.json" -Raw | ConvertFrom-Json
        $cleanup = Get-Content "$data/garrycraft-source-shadow-cleanup.json" -Raw | ConvertFrom-Json
        $checks["$phase-shadowDraws"] = $capture.captures.on.native.castDraws -gt $capture.captures.off.native.castDraws
        $checks["$phase-shadowPixel"] = $capture.captures.on.pixel[0] -lt $capture.captures.off.pixel[0] - 8
        $checks["$phase-validDraws"] = $cleanup.invalidMeshes -eq 0 -and $cleanup.wrongThread -eq 0
        $checks["$phase-cleanup"] = $cleanup.registered -eq 0
        if ($phase -eq 'late-reopen') {
            $lateFirst = Get-Content "$RunRoot/late-first-compatibility.json" -Raw | ConvertFrom-Json
            $checks.laterHookStillCalled = $compatibility.fixtureCalls -gt $lateFirst.fixtureCalls
        }
        foreach ($suffix in 'path.json', 'cleanup.json', 'off.png', 'on.png', 'bounds.json') {
            Copy-Item -LiteralPath "$data/garrycraft-source-shadow-$suffix" -Destination "$RunRoot/$phase-$suffix"
        }
    }
    Send 'lua_run_cl garrycraft_bridge.close() garrycraft_shadow_test.restore() garrycraft_bridge.close()'
    Remove-Item -LiteralPath "$data/garrycraft-shadow-fallback.json" -ErrorAction SilentlyContinue
    Send "lua_run_cl RunString(file.Read('garrycraft-shadow-fallback.lua','DATA'))"
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath "$data/garrycraft-shadow-fallback.json")) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'The shadow fallback probe did not report.' }
        Start-Sleep -Milliseconds 250
    }
    $fallback = Get-Content "$data/garrycraft-shadow-fallback.json" -Raw | ConvertFrom-Json
    $checks.fallbackUpdatesComplete = $fallback.updatesCompleted -and $fallback.entityValid
    $checks.fallbackMeshDraws = $fallback.meshDraws -gt 0
    $checks.fallbackShadowsDisabled = $fallback.shadowsDisabled -and -not $fallback.native.installed
    $checks.fallbackSpecificReason = $fallback.native.installFailure -match 'VStudioRender025 mesh-count callback'
    $checks.fallbackNoReferences = $fallback.native.registered -eq 0
    Copy-Item "$data/garrycraft-shadow-fallback.*" $RunRoot
    $console = Get-Content "$lab/garrysmod/console.log" -Raw
    $checks.fallbackWarnsOnce = ([regex]::Matches($console, '\[GarryCraft\] Custom mesh shadows are unavailable\.')).Count -eq 1
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; game=$lab} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/result.json"
    if (-not $passed) { throw 'Read the shadow captures and result.json.' }
    Get-Content "$RunRoot/result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; game=$lab} |
        ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/result.json"
    throw
} finally {
    Copy-Item -LiteralPath "$lab/garrysmod/console.log" -Destination "$RunRoot/source-console.log"
}
