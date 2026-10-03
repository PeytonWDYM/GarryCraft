param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot, [Parameter(Mandatory)][ValidateSet('source','minecraft')][string]$Mode,
    [Parameter(Mandatory)][ushort]$UseKey, [ValidateRange(1,9)][int]$GunSlot = 1)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$destination = "$RunRoot/artifacts/physgun"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/physgun-native.lua" "$data/garrycraft-physgun-native.lua"
. "$PSScriptRoot/SourceInput.ps1"
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Mark($Label) { Send "lua_run GarryCraft.PhysgunNativeTest.Mark('$Label')" }
function Snapshot($Label) { Send "lua_run GarryCraft.PhysgunNativeTest.Snapshot('$Label')" }
function Stage($Name) { Send "lua_run GarryCraft.PhysgunNativeTest.Stage('$Name')"; Start-Sleep -Milliseconds 500 }
function FreezeFixture($Name) {
    Mark "group-freeze-$Name"
    [GarryCraftSourceInput]::MouseDown('left')
    Start-Sleep -Milliseconds 600
    [GarryCraftSourceInput]::MouseDown('right')
    Start-Sleep -Milliseconds 100
    [GarryCraftSourceInput]::MouseUp('right')
    [GarryCraftSourceInput]::MouseUp('left')
    Start-Sleep -Milliseconds 500
    Snapshot "group-freeze-$Name-result"
}
$game = Get-Process -Id $GamePid
$referencePath = "$destination/garrycraft-physgun-source.json"
$referenceResultPath = "$destination/source-result.json"
$reference = $null
if ($Mode -eq 'minecraft') {
    if (-not (Test-Path -LiteralPath $referencePath) -or -not (Test-Path -LiteralPath $referenceResultPath)) {
        throw 'Run the Source reference pass in this run directory first.'
    }
    $reference = Get-Content -LiteralPath $referencePath -Raw | ConvertFrom-Json
    $referenceResult = Get-Content -LiteralPath $referenceResultPath -Raw | ConvertFrom-Json
    if (-not $referenceResult.passed -or $referenceResult.useKey -ne $UseKey) {
        throw 'The Source reference must pass with the same configured Use key.'
    }
    if (@($reference.snapshots | Where-Object label -eq 'group-reload-result').Count -ne 1) {
        throw 'Rerun the Source reference with the current constrained-pair scenario.'
    }
    Copy-Item -LiteralPath $referencePath -Destination "$data/garrycraft-physgun-reference.json"
}
foreach ($previous in @("$destination/garrycraft-physgun-$Mode.json", "$destination/$Mode-result.json")) {
    if (Test-Path -LiteralPath $previous) {
        Copy-Item -LiteralPath $previous -Destination ($previous -replace '\.json$', ('-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff') + '.json'))
    }
}
$record = "$data/garrycraft-physgun-$Mode.json"
if (Test-Path -LiteralPath $record) { Remove-Item -LiteralPath $record }
if (Test-Path -LiteralPath "$data/garrycraft-physgun-client.json") { Remove-Item -LiteralPath "$data/garrycraft-physgun-client.json" }
[GarryCraftSourceInput]::Focus($game.MainWindowHandle)
Start-Sleep -Milliseconds 700
if ($Mode -eq 'minecraft') {
    # Foreground activation can move Source's mouse before its camera consumes the new pose.
    Send "lua_run_cl local r=util.JSONToTable(file.Read('garrycraft-physgun-reference.json','DATA')) LocalPlayer():SetEyeAngles(Angle(unpack(r.fixture.aim)))"
    Start-Sleep -Milliseconds 700
}
Send "lua_run_cl RunString(file.Read('garrycraft-physgun-native.lua','DATA'))"
$geometry = if ($Mode -eq 'minecraft') { "util.JSONToTable(file.Read('garrycraft-physgun-reference.json','DATA')).fixture" } else { 'nil' }
Send "lua_run RunString(file.Read('garrycraft-physgun-native.lua','DATA')) GarryCraft.PhysgunNativeTest.Begin('$Mode',$geometry)"
Start-Sleep -Milliseconds 500
if (-not (Test-Path -LiteralPath $record)) { throw 'The native gun fixture did not start. Read the Source console log.' }
$actions = @()
try {
    Mark 'pickup'
    [GarryCraftSourceInput]::MouseDown('left')
    Start-Sleep -Seconds 2
    Snapshot 'pickup-result'
    Mark 'wheel-out'
    [GarryCraftSourceInput]::Wheel(360)
    Start-Sleep -Seconds 2
    Snapshot 'wheel-out-result'
    Mark 'wheel-in'
    [GarryCraftSourceInput]::Wheel(-360)
    # Allow the native body to finish returning from the maximum wheel-out distance before comparing it.
    Start-Sleep -Seconds 2
    Snapshot 'wheel-in-result'
    Mark 'rotate'
    [GarryCraftSourceInput]::KeyDown($UseKey)
    Start-Sleep -Milliseconds 200
    [GarryCraftSourceInput]::Relative(160, 30)
    Start-Sleep -Milliseconds 600
    [GarryCraftSourceInput]::KeyUp($UseKey)
    Snapshot 'rotate-result'
    Mark 'snap'
    [GarryCraftSourceInput]::KeyDown($UseKey)
    [GarryCraftSourceInput]::KeyDown(0x10)
    Start-Sleep -Milliseconds 200
    [GarryCraftSourceInput]::Relative(80, -60)
    Start-Sleep -Milliseconds 600
    [GarryCraftSourceInput]::KeyUp(0x10)
    [GarryCraftSourceInput]::KeyUp($UseKey)
    Snapshot 'snap-result'
    Mark 'forward-distance'
    [GarryCraftSourceInput]::KeyDown($UseKey)
    [GarryCraftSourceInput]::Hold(0x57, 600)
    Snapshot 'forward-distance-result'
    Mark 'back-distance'
    [GarryCraftSourceInput]::Hold(0x53, 600)
    [GarryCraftSourceInput]::KeyUp($UseKey)
    Start-Sleep -Seconds 1
    Snapshot 'back-distance-result'
    Mark 'freeze'
    [GarryCraftSourceInput]::MouseDown('right')
    Start-Sleep -Milliseconds 100
    [GarryCraftSourceInput]::MouseUp('right')
    [GarryCraftSourceInput]::MouseUp('left')
    Start-Sleep -Seconds 1
    Snapshot 'freeze-result'
    Mark 'reload'
    [GarryCraftSourceInput]::Key(0x52)
    Start-Sleep -Seconds 1
    Snapshot 'reload-result'
    Mark 'release'
    [GarryCraftSourceInput]::MouseDown('left')
    Start-Sleep -Milliseconds 500
    [GarryCraftSourceInput]::MouseUp('left')
    Start-Sleep -Milliseconds 500
    Snapshot 'release-result'
    Stage 'target'
    FreezeFixture 'target'
    Stage 'pairA'
    FreezeFixture 'pairA'
    Stage 'pairB'
    FreezeFixture 'pairB'
    Snapshot 'group-frozen-result'
    Stage 'away'
    Snapshot 'group-reload-ray'
    Start-Sleep -Milliseconds 250
    $ray = (Get-Content -LiteralPath $record -Raw | ConvertFrom-Json).snapshots[-1]
    if ($ray.trace.hitNonWorld) { throw 'Double reload requires an equivalent world or sky ray in both passes.' }
    Mark 'group-reload'
    [GarryCraftSourceInput]::KeyDown(0x52)
    Start-Sleep -Milliseconds 60
    [GarryCraftSourceInput]::KeyUp(0x52)
    Start-Sleep -Milliseconds 60
    [GarryCraftSourceInput]::KeyDown(0x52)
    Start-Sleep -Milliseconds 60
    [GarryCraftSourceInput]::KeyUp(0x52)
    Start-Sleep -Seconds 1
    Snapshot 'group-reload-result'
    if ($Mode -eq 'minecraft') {
        Send "lua_run_cl LocalPlayer():SetEyeAngles(Angle($($reference.fixture.aim[0]),$($reference.fixture.aim[1]),0))"
        Start-Sleep -Milliseconds 500
        Stage 'target'
        Mark 'idle-wheel'
        Snapshot 'idle-wheel-before'
        [GarryCraftSourceInput]::Wheel(360)
        Start-Sleep -Milliseconds 400
        [GarryCraftSourceInput]::Wheel(-360)
        Start-Sleep -Milliseconds 400
        Snapshot 'idle-wheel-result'
        Mark 'slot-pickup'
        [GarryCraftSourceInput]::MouseDown('left')
        Start-Sleep -Milliseconds 700
        Snapshot 'slot-pickup-result'
        Mark 'slot-release'
        $otherSlot = if ($GunSlot -eq 9) { 1 } else { $GunSlot + 1 }
        [GarryCraftSourceInput]::Key([ushort](0x30 + $otherSlot))
        Start-Sleep -Milliseconds 600
        Snapshot 'slot-release-result'
        [GarryCraftSourceInput]::MouseUp('left')
        Mark 'slot-return'
        [GarryCraftSourceInput]::Key([ushort](0x30 + $GunSlot))
        Start-Sleep -Milliseconds 600
        Snapshot 'slot-return-result'
        Stage 'target'
        Mark 'menu-pickup'
        [GarryCraftSourceInput]::MouseDown('left')
        Start-Sleep -Milliseconds 700
        Snapshot 'menu-pickup-result'
        Mark 'menu-open'
        [GarryCraftSourceInput]::Key(0x49)
        Start-Sleep -Milliseconds 700
        Snapshot 'menu-open-result'
        [GarryCraftSourceInput]::MouseUp('left')
        Mark 'menu-click'
        [GarryCraftSourceInput]::Click(.95,.95)
        [GarryCraftSourceInput]::Wheel(120)
        Start-Sleep -Milliseconds 500
        Snapshot 'menu-click-result'
        Mark 'menu-close'
        [GarryCraftSourceInput]::MouseDown('left')
        [GarryCraftSourceInput]::MouseDown('right')
        [GarryCraftSourceInput]::Key(0x1B)
        Start-Sleep -Milliseconds 400
        Snapshot 'menu-close-held-result'
        [GarryCraftSourceInput]::MouseUp('right')
        [GarryCraftSourceInput]::MouseUp('left')
        Start-Sleep -Milliseconds 500
        Snapshot 'menu-close-result'
        Mark 'menu-resume'
        [GarryCraftSourceInput]::MouseDown('left')
        Start-Sleep -Milliseconds 600
        Snapshot 'menu-resume-result'
        [GarryCraftSourceInput]::MouseUp('left')
        Mark 'walk-viewmodel'
        [GarryCraftSourceInput]::Hold(0x57,600)
        Start-Sleep -Milliseconds 400
        Snapshot 'walk-viewmodel-result'
        Mark 'jump-viewmodel'
        [GarryCraftSourceInput]::Key(0x20)
        Start-Sleep -Seconds 1
        Snapshot 'jump-viewmodel-result'
    }
    $actions = @('left down', 'wheel +360', 'wheel -360', 'Use + mouse(160,30)',
        'Use + Shift + mouse(80,-60)', 'Use + W 600ms', 'Use + S 600ms', 'right click', 'left up', 'R', 'left click',
        'native freeze target and welded pair', 'empty-ray double R 120ms apart')
    if ($Mode -eq 'minecraft') { $actions += @('idle wheel +360/-360', 'number slot away/return', 'I inventory',
        'menu click and wheel', 'Escape with mouse held', 'fresh left click', 'walk W600ms', 'jump Space') }
} finally {
    $released = [GarryCraftSourceInput]::Release()
    Send "lua_run GarryCraft.PhysgunNativeTest.Finish()"
    Send "lua_run_cl hook.Remove('Think','GarryCraftPhysgunNativeProbe') hook.Remove('PostDrawViewModel','GarryCraftPhysgunNativeProbe') hook.Remove('DrawPhysgunBeam','GarryCraftPhysgunNativeProbe')"
    Start-Sleep -Milliseconds 200
    if (Test-Path -LiteralPath $record) { Copy-Item -LiteralPath $record -Destination $destination }
    if (Test-Path -LiteralPath "$data/garrycraft-physgun-client.json") {
        Copy-Item -LiteralPath "$data/garrycraft-physgun-client.json" -Destination "$destination/$Mode-client.json"
    }
}
$run = Get-Content "$destination/garrycraft-physgun-$Mode.json" -Raw | ConvertFrom-Json
function Row($Label) { @($run.snapshots | Where-Object label -eq $Label)[-1] }
function Distance($Left, $Right) {
    $squared = 0.0
    for ($axis = 0; $axis -lt 3; $axis++) { $squared += [Math]::Pow($Left[$axis] - $Right[$axis], 2) }
    [Math]::Sqrt($squared)
}
function AngleError($Left, $Right) {
    $largest = 0.0
    for ($axis = 0; $axis -lt 3; $axis++) {
        $difference = [Math]::Abs($Left[$axis] - $Right[$axis]) % 360
        $largest = [Math]::Max($largest, [Math]::Min($difference, 360 - $difference))
    }
    $largest
}
$begin = Row 'begin'
$pickup = Row 'pickup-result'
$out = Row 'wheel-out-result'
$back = Row 'wheel-in-result'
$rotate = Row 'rotate-result'
$snap = Row 'snap-result'
$forward = Row 'forward-distance-result'
$backward = Row 'back-distance-result'
$freeze = Row 'freeze-result'
$reload = Row 'reload-result'
$release = Row 'release-result'
$groupFrozen = Row 'group-frozen-result'
$groupReload = Row 'group-reload-result'
$angleChange = 0
for ($axis = 0; $axis -lt 3; $axis++) { $angleChange += [Math]::Abs($rotate.entities.target.angles[$axis] - $pickup.entities.target.angles[$axis]) }
$checks = [ordered]@{
    finished = $run.finished -and $run.reason -eq 'complete'
    actualNativeGun = @($run.samples | Where-Object { $_.step -notlike 'slot-*' -and $_.step -notlike 'menu-*' -and $_.weapon -ne 'weapon_physgun' }).Count -eq 0
    pickedUp = $pickup.held -eq $pickup.entities.target.id -and $pickup.entities.target.heldByPlayer
    wheelChangesDistance = [Math]::Abs($out.entities.target.eyeDistance - $pickup.entities.target.eyeDistance) -gt 3
    wheelChangesBothDirections = $back.entities.target.eyeDistance -lt $out.entities.target.eyeDistance - 3
    rotates = $angleChange -gt 5
    forwardDistance = [Math]::Abs($forward.entities.target.eyeDistance - $snap.entities.target.eyeDistance) -gt 3
    backDistance = [Math]::Abs($backward.entities.target.eyeDistance - $forward.entities.target.eyeDistance) -gt 3
    freezeEvent = @($run.events | Where-Object name -eq 'freeze').Count -gt 0
    frozen = -not $freeze.entities.target.motion
    reloadEvent = @($run.events | Where-Object name -eq 'reload').Count -gt 0
    reloadUnfreezes = $reload.entities.target.motion
    released = $release.held -eq -1 -and -not $release.entities.target.heldByPlayer
    realWheelCommands = @($run.commands | Where-Object wheel -ne 0).Count -gt 0
    realMouseCommands = @($run.commands | Where-Object { $_.mouseX -ne 0 -or $_.mouseY -ne 0 }).Count -gt 0
    realUseCommands = @($run.commands | Where-Object { ($_.buttons -band 32) -ne 0 }).Count -gt 0
    weldedPairFrozen = -not $groupFrozen.entities.pairA.motion -and -not $groupFrozen.entities.pairB.motion
    ownedGroupFrozen = -not $groupFrozen.entities.target.motion
    eachBodyFrozenByGun = @('target','pairA','pairB' | Where-Object {
        $name = $_
        @($run.events | Where-Object { $_.name -eq 'freeze' -and $_.step -eq "group-freeze-$name" }).Count -eq 0
    }).Count -eq 0
    doubleReloadEvents = @($run.events | Where-Object { $_.name -eq 'reload' -and $_.step -eq 'group-reload' }).Count -eq 2
    doubleReloadUnfreezesAll = $groupReload.entities.target.motion -and $groupReload.entities.pairA.motion -and $groupReload.entities.pairB.motion
    nativeUnfreezeEvents = @('target','pairA','pairB' | Where-Object {
        $id = $groupReload.entities.$_.id
        @($run.events | Where-Object { $_.name -eq 'unfreeze' -and $_.step -eq 'group-reload' -and $_.entity -eq $id }).Count -eq 0
    }).Count -eq 0
    completeRecording = -not $run.commandsTruncated -and -not $run.samplesTruncated
    inputReleased = $released
}
$comparison = @()
if ($Mode -eq 'minecraft') {
    $referenceBegin = @($reference.snapshots | Where-Object label -eq 'begin')[-1]
    $checks.referenceGeometry = (Distance $run.fixture.eye $reference.fixture.eye) -lt .01 -and (AngleError $run.fixture.aim $reference.fixture.aim) -lt .01
    $checks.referenceMap = $run.map -eq $reference.map
    $checks.referenceEye = (Distance $begin.eye $referenceBegin.eye) -lt 1
    $checks.referenceAim = (AngleError $begin.aim $referenceBegin.aim) -lt .5
    $referencePickup = @($reference.snapshots | Where-Object label -eq 'pickup-result')[-1]
    $checks.referenceUseBinding = $pickup.client.useBinding -eq $referencePickup.client.useBinding
    $checks.referenceConvars = @($run.convars.PSObject.Properties | Where-Object {
        $_.Value -ne $reference.convars.($_.Name)
    }).Count -eq 0
    foreach ($label in @('pickup-result','wheel-out-result','wheel-in-result','rotate-result','snap-result',
            'forward-distance-result','back-distance-result','freeze-result','reload-result','release-result')) {
        $native = @($reference.snapshots | Where-Object label -eq $label)[-1]
        $minecraft = Row $label
        $comparison += [ordered]@{step = $label; referenceDistance = $native.entities.target.eyeDistance;
            minecraftDistance = $minecraft.entities.target.eyeDistance;
            distanceError = [Math]::Abs($native.entities.target.eyeDistance - $minecraft.entities.target.eyeDistance);
            angleError = AngleError $native.entities.target.angles $minecraft.entities.target.angles;
            sameMotion = $native.entities.target.motion -eq $minecraft.entities.target.motion;
            sameHold = $native.entities.target.heldByPlayer -eq $minecraft.entities.target.heldByPlayer}
    }
    $checks.referenceMotionAndHold = @($comparison | Where-Object { -not $_.sameMotion -or -not $_.sameHold }).Count -eq 0
    $checks.referenceDistances = @($comparison | Where-Object distanceError -gt 8).Count -eq 0
    $checks.referenceRotation = @($comparison | Where-Object angleError -gt 5).Count -eq 0
    $slotPickup = Row 'slot-pickup-result'
    $slotRelease = Row 'slot-release-result'
    $slotReturn = Row 'slot-return-result'
    $menuPickup = Row 'menu-pickup-result'
    $menuOpen = Row 'menu-open-result'
    $menuClick = Row 'menu-click-result'
    $menuCloseHeld = Row 'menu-close-held-result'
    $menuClose = Row 'menu-close-result'
    $menuResume = Row 'menu-resume-result'
    $idleWheelBefore = Row 'idle-wheel-before'
    $idleWheel = Row 'idle-wheel-result'
    $checks.idleWheelKeepsGun = $idleWheel.weapon -eq 'weapon_physgun' -and $idleWheel.client.slot -eq $idleWheelBefore.client.slot
    $checks.idleWheelDoesNotPickUp = $idleWheel.held -eq -1 -and -not $idleWheel.entities.target.heldByPlayer
    $checks.idleWheelHidesSourceSelection = $idleWheel.client.weaponSelectionAllowed -eq $false
    $checks.heldWheelHidesSourceSelection = $out.client.weaponSelectionAllowed -eq $false -and $back.client.weaponSelectionAllowed -eq $false
    $checks.slotStartsHeld = $slotPickup.entities.target.heldByPlayer
    $checks.slotReleases = $slotRelease.held -eq -1 -and -not $slotRelease.entities.target.heldByPlayer -and $slotRelease.weapon -eq 'weapon_garrycraft'
    $checks.numberedSlotChanged = $slotRelease.client.slot -eq $otherSlot - 1
    $checks.slotReturnsGun = $slotReturn.weapon -eq 'weapon_physgun' -and $slotReturn.client.slot -eq $GunSlot - 1
    $checks.menuStartsHeld = $menuPickup.entities.target.heldByPlayer
    $checks.inventoryOpensAndDrops = $menuOpen.client.screenOpen -and $menuOpen.held -eq -1 -and -not $menuOpen.entities.target.heldByPlayer -and $menuOpen.weapon -eq 'weapon_garrycraft'
    $checks.menuInputDoesNotPickUp = $menuClick.client.screenOpen -and $menuClick.held -eq -1 -and @($run.events | Where-Object { $_.step -eq 'menu-click' -and $_.name -eq 'pickup' }).Count -eq 0
    $checks.closeHasNoStalePickup = -not $menuCloseHeld.client.screenOpen -and $menuCloseHeld.held -eq -1 -and $menuClose.held -eq -1 -and @($run.events | Where-Object { $_.step -eq 'menu-close' -and $_.name -eq 'pickup' }).Count -eq 0
    $checks.inventoryClosesAndRestoresGun = -not $menuClose.client.screenOpen -and $menuClose.weapon -eq 'weapon_physgun'
    $checks.freshClickResumes = $menuResume.entities.target.heldByPlayer
    $walk = Row 'walk-viewmodel-result'
    $jump = Row 'jump-viewmodel-result'
    $frames = @($jump.client.viewmodelFrames)
    $checks.walkMovesPlayer = (Distance $walk.playerPosition $menuResume.playerPosition) -gt 10
    $jumpSamples = @($run.samples | Where-Object step -eq 'jump-viewmodel')
    $jumpHeights = @($jumpSamples | ForEach-Object { $_.playerPosition[2] })
    $jumpRange = $jumpHeights | Measure-Object -Minimum -Maximum
    $checks.jumpMovesPlayer = $jumpSamples.Count -gt 5 -and ($jumpRange.Maximum - $jumpRange.Minimum) -gt 8
    $checks.realJumpCommands = @($run.commands | Where-Object { $_.step -eq 'jump-viewmodel' -and ($_.buttons -band 2) -ne 0 }).Count -gt 0
    $checks.walkAndJumpViewmodelFrames = @($frames | Where-Object phase -eq 'walk-viewmodel').Count -gt 10 -and @($frames | Where-Object phase -eq 'jump-viewmodel').Count -gt 10
    $offsetSteps = @()
    for ($index = 1; $index -lt $frames.Count; $index++) {
        if ($frames[$index].phase -eq $frames[$index - 1].phase) {
            $offsetSteps += Distance $frames[$index].offset $frames[$index - 1].offset
        }
    }
    $checks.viewmodelStaysWithCamera = $offsetSteps.Count -gt 0 -and @($offsetSteps | Where-Object { $_ -gt 4 }).Count -eq 0
}
$passed = -not ($checks.Values -contains $false)
@{passed=$passed;mode=$Mode;checks=$checks;actions=$actions;fixture=$run.fixture;useKey=$UseKey;gunSlot=$GunSlot;
    comparison=$comparison;reference=if ($Mode -eq 'minecraft') { $referencePath } else { $null };
    inputMethod='Windows SendInput to the owned Source HWND'} | ConvertTo-Json -Depth 8 |
    Set-Content "$destination/$Mode-result.json"
Get-Content "$destination/$Mode-result.json"
if (-not $passed) { throw 'Native gun input checks failed. Read the paired native event and physics traces.' }
