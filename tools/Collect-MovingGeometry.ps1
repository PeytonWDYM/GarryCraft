param(
    [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $LabPath '.garrycraft-lab'))) { throw 'The installation requires a .garrycraft-lab marker' }
$source = Join-Path $LabPath 'garrysmod/data/garrycraft-moving-geometry.json'
$trace = Get-Content -LiteralPath $source -Raw | ConvertFrom-Json
if ($trace.phases.Count -ne 12) { throw 'The moving geometry trace is incomplete' }
if ($trace.phases[0].actors.Count -ne 2) { throw 'The trace requires the owned prop and NPC actor checks' }
$checks = [System.Collections.Generic.List[object]]::new()
foreach ($phase in $trace.phases) {
    $received = @($phase.minecraft.bodies | Where-Object entity -EQ $phase.entity)
    $actual = @($received | ForEach-Object { $_.triangles } | ForEach-Object { ,$_ })
    $expected = @($phase.triangles)
    $maximumError = 0.0
    $equal = $actual.Count -eq $expected.Count
    if ($equal) {
        for ($triangle = 0; $triangle -lt $expected.Count; $triangle++) {
            for ($coordinate = 0; $coordinate -lt 9; $coordinate++) {
                $coordinateError = [Math]::Abs([double]$actual[$triangle][$coordinate] - [double]$expected[$triangle][$coordinate])
                $maximumError = [Math]::Max($maximumError, $coordinateError)
            }
        }
    }
    $checks.Add([pscustomobject]@{ name = $phase.phase; passed = $equal -and $maximumError -le 0.00003;
        expectedTriangles = $expected.Count; receivedTriangles = $actual.Count; maximumErrorBlocks = $maximumError })
    if ($phase.creation -ge 0 -and $received.Count -gt 0) {
        $checks.Add([pscustomobject]@{name = "$($phase.phase)-creation"; passed = @($received | Where-Object creation -NE $phase.creation).Count -eq 0})
    }
    $receivedActors = @($phase.minecraft.actors | Where-Object { $_.id -in $phase.actorIds })
    $checks.Add([pscustomobject]@{name = "$($phase.phase)-actor-count"; passed = $receivedActors.Count -eq $phase.actors.Count})
    foreach ($actor in $phase.actors) {
        $actualActor = @($phase.minecraft.actors | Where-Object id -EQ $actor.id)
        $actorMatches = $actualActor.Count -eq 1
        if ($actorMatches) {
            $actorMatches = $actualActor[0].generation -eq $actor.generation -and $actualActor[0].name -ceq $actor.name -and $actualActor[0].npc -eq $actor.npc
            foreach ($field in @('x', 'y', 'z', 'yaw', 'width', 'height')) {
                if ([Math]::Abs([double]$actualActor[0].$field - [double]$actor.$field) -gt 0.00003) { $actorMatches = $false }
            }
        }
        $checks.Add([pscustomobject]@{name = "$($phase.phase)-actor-$($actor.id)"; passed = $actorMatches})
    }
}
$unchanged = $trace.phases | Where-Object phase -EQ 'unchanged'
$checks.Add([pscustomobject]@{name = 'unchanged-cache'; passed = $unchanged.source.meshReads -eq 0 -and $unchanged.source.pendingShapes -eq 0 -and $unchanged.minecraft.rebuilt -eq 0})
$checks.Add([pscustomobject]@{name = 'skipped-shape-packets'; passed = $trace.droppedPackets -eq 3})
$result = [pscustomobject]@{ passed = @($checks | Where-Object passed -EQ $false).Count -eq 0;
    toleranceBlocks = 0.00003; checks = $checks;
    recycledEntityIndex = $trace.phases[0].entity -eq $trace.phases[-1].entity }
$artifacts = Join-Path $RunRoot 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $artifacts 'moving-geometry-trace.json')
$destination = Join-Path $artifacts 'moving-geometry-result.json'
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $destination
$result
if (-not $result.passed) { throw "Moving geometry checks failed. Read $destination" }
