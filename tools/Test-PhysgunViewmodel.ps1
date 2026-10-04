param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot, [ValidateRange(1,9)][int]$GunSlot = 1,
    [ValidateRange(1,9)][int]$OtherSlot = 2, [switch]$MissingSourceHands)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$destination = "$RunRoot/artifacts/physgun-viewmodel$(if ($MissingSourceHands) { '-no-source-hands' })"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/physgun-viewmodel.lua" "$data/garrycraft-physgun-viewmodel.lua"
. "$PSScriptRoot/SourceInput.ps1"
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $command }
function Mark($label) { Send "lua_run_cl GarryCraft.PhysgunViewmodelTest.Mark('$label')" }
$request = [Guid]::NewGuid().ToString('N')
$record = "$data/garrycraft-physgun-viewmodel.json"
function Wait-Record([bool]$Finished) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if (Test-Path -LiteralPath $record) {
            try { $observed = Get-Content -LiteralPath $record -Raw | ConvertFrom-Json }
            catch { $observed = $null }
            if ($observed.label -eq $request -and [bool]$observed.finished -eq $Finished) { return $observed }
        }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "The viewmodel probe did not acknowledge finished=$Finished. Read the Source console log."
}
$game = Get-Process -Id $GamePid
[GarryCraftSourceInput]::Focus($game.MainWindowHandle)
try {
    if ($MissingSourceHands) { Send 'lua_run Entity(1):GetHands():Remove()' }
    Send "lua_run_cl RunString(file.Read('garrycraft-physgun-viewmodel.lua','DATA')) GarryCraft.PhysgunViewmodelTest.Begin('$request')"
    Wait-Record $false | Out-Null
    Start-Sleep -Seconds 1
    Mark 'walk'
    [GarryCraftSourceInput]::KeyDown(0x57)
    Start-Sleep -Seconds 2
    Mark 'sprint'
    [GarryCraftSourceInput]::KeyDown(0x10)
    Start-Sleep -Seconds 2
    [GarryCraftSourceInput]::KeyUp(0x10)
    [GarryCraftSourceInput]::KeyUp(0x57)
    Start-Sleep -Seconds 2
    Mark 'stop'
    Start-Sleep -Seconds 1
    [GarryCraftSourceInput]::Hold([ushort](0x30 + $OtherSlot), 100)
    Start-Sleep -Milliseconds 700
    Mark 'switch-away'
    Start-Sleep -Seconds 1
    [GarryCraftSourceInput]::Hold([ushort](0x30 + $GunSlot), 100)
    Start-Sleep -Milliseconds 700
    Mark 'switch-back'
    Start-Sleep -Seconds 1
} finally {
    [GarryCraftSourceInput]::KeyUp(0x57)
    [GarryCraftSourceInput]::KeyUp(0x10)
    if ($MissingSourceHands) { Send 'lua_run Entity(1):SetupHands()' }
    Send 'lua_run_cl GarryCraft.PhysgunViewmodelTest.Finish()'
}
$run = Wait-Record $true
Copy-Item "$data/garrycraft-physgun-viewmodel*" $destination -Force
$frames = @($run.frames | Where-Object { $_.active })
$checks = [ordered]@{
    finished = $run.finished -eq $true
    allImages = @($run.images).Count -eq 6
    selectedGun = $frames.Count -gt 100
    minecraftArms = @($frames | Where-Object { $_.native.leftArm.vertices -eq 0 -or $_.native.rightArm.vertices -eq 0 }).Count -eq 0
    handsSuppressed = @($frames | Where-Object { -not $_.native.sourceHandsSuppressed }).Count -eq 0
    armsDrawn = @($frames | Where-Object { $_.native.armsDrawn -le 0 }).Count -eq 0
    rearElbowFollowsGun = @($frames | Where-Object { $_.native.rearElbowError -gt .001 }).Count -eq 0
    sprintSeen = @($frames | Where-Object { $_.phase -eq 'sprint' -and $_.sprinting }).Count -gt 10
    stoppedBob = @($frames | Where-Object { $_.phase -eq 'stop' -and $_.bob -gt .001 }).Count -eq 0
    switchAway = @($run.images | Where-Object { $_.phase -eq 'switch-away' -and -not $_.equipped }).Count -eq 1
    switchBack = @($run.images | Where-Object { $_.phase -eq 'switch-back' -and $_.equipped }).Count -eq 1
}
$maxPoseError = 0.0
$maxRotationError = 0.0
foreach ($frame in $frames) {
    $pose = $frame.minecraftPose
    $actual = $frame.measuredTransform
    if (@($pose).Count -ne 12 -or @($actual).Count -ne 12) {
        $maxPoseError = [double]::PositiveInfinity
        $maxRotationError = [double]::PositiveInfinity
        break
    }
    for ($axis = 0; $axis -lt 3; $axis++) {
        $row = $axis * 4
        for ($column = 0; $column -lt 4; $column++) {
            $expected = $pose[$row+$column]
            if ($column -eq 3) {
                $maxPoseError = [Math]::Max($maxPoseError, [Math]::Abs($expected - $actual[$row+$column]))
            } else {
                $maxRotationError = [Math]::Max($maxRotationError, [Math]::Abs($expected - $actual[$row+$column]))
            }
        }
    }
}
$checks.minecraftPoseApplied = $maxPoseError -lt .001
$checks.minecraftRotationApplied = $maxRotationError -lt .0001
$walk = @($frames | Where-Object { $_.phase -eq 'walk' })
$checks.walkBobVaries = ($walk.bobPose.translationY | Measure-Object -Maximum).Maximum - ($walk.bobPose.translationY | Measure-Object -Minimum).Minimum -gt .1
$report = [ordered]@{checks = $checks; passed = -not ($checks.Values -contains $false); frames = $frames.Count;
    maxPoseError = $maxPoseError; maxRotationError = $maxRotationError}
$report | ConvertTo-Json -Depth 4 | Set-Content "$destination/result.json"
$report
if (-not $report.passed) { throw 'Read the viewmodel trace and the six screenshots.' }
