param([Parameter(Mandatory)][string]$RunRoot, [Parameter(Mandatory)][string]$LabPath)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Map probes require the owned Source lab.' }
$minecraft = Get-Content -LiteralPath "$RunRoot/artifacts/map-probes.json" -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath "$LabPath/garrysmod/data/garrycraft-map-probes-source.json" -Raw | ConvertFrom-Json
if ($minecraft.request -ne $source.request) { throw 'Map collision traces describe different requests.' }
$checks = @($minecraft.results | ForEach-Object {
    [ordered]@{name=$_.name; rayHit=$_.rayHit; bodyStopped=$_.bodyStopped;
        rayMatches=[Math]::Abs($_.sourceRay-$_.importedRay) -lt .001}
})
Copy-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-map-probes-source.json" -Destination "$RunRoot/artifacts"
$passed = $checks.Count -eq $source.probes.Count -and $checks.Count -gt 0 -and
    @($checks | Where-Object { -not $_.rayHit -or -not $_.bodyStopped -or -not $_.rayMatches }).Count -eq 0
@{request=$minecraft.request;passed=$passed;checks=$checks} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath "$RunRoot/artifacts/map-probe-results.json"
Get-Content -LiteralPath "$RunRoot/artifacts/map-probe-results.json"
if (-not $passed) { throw 'Map collision probes failed. Read the paired traces.' }
