param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab", [switch]$DepthShadow)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-lighting-source.json" -Destination $destination
$minecraft = Get-Content -Raw "$destination\lighting-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-lighting-source.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or -not $minecraft.completed) { throw 'Lighting traces describe different or incomplete scenarios.' }
$samples = $source.samples
if ($DepthShadow) {
    Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-depthshadow-source.json" -Destination $destination
    $depth = Get-Content -Raw "$destination\garrycraft-depthshadow-source.json" | ConvertFrom-Json
    if ($depth.session -ne $source.session -or -not $depth.samePose) { throw 'Depth-shadow captures need the same session and camera pose.' }
    foreach ($sample in $depth.samples.PSObject.Properties.Value) {
        Copy-Item -LiteralPath (Join-Path "$LabPath\garrysmod\data" $sample.screenshot) -Destination $destination
    }
    if ($depth.darkenedPixels -eq 0) { throw 'Depth-shadow pixels show no darkening. Inspect both captures before reporting engine support.' }
}
foreach ($sample in $samples.PSObject.Properties.Value) {
    Copy-Item -LiteralPath (Join-Path "$LabPath\garrysmod\data" $sample.screenshot) -Destination $destination
}
$tint = $samples.wall.water.tints[0]
$offGrid = $samples.shadowOff.shadowGrid
$onGrid = $samples.shadowOn.shadowGrid
$sameGrid = $offGrid.width -eq $onGrid.width -and $offGrid.height -eq $onGrid.height -and
    $offGrid.columns -eq $onGrid.columns -and $offGrid.rows -eq $onGrid.rows -and
    $offGrid.pixels.Count -eq $onGrid.pixels.Count -and $offGrid.pixels.Count -gt 0
$darkenedPixels = 0
if ($sameGrid) {
    for ($index = 0; $index -lt $offGrid.pixels.Count; $index++) {
        if ($offGrid.pixels[$index] - $onGrid.pixels[$index] -gt 5) { $darkenedPixels++ }
    }
}
$results = [ordered]@{
    dark = $samples.dark.modelLights -eq 0
    floor = $samples.floor.modelLights -gt 0 -and $samples.floor.lights.allocated -gt 0 -and $samples.floor.floorLight[0] -gt 0
    wall = $samples.wall.modelLights -ge 2 -and $samples.wall.lights.allocated -ge 2
    far = $samples.far.modelLights -eq $samples.wall.modelLights -and $samples.far.lights.allocated -ge 2
    budget = $samples.budget.lights.exported -gt 32 -and $samples.budget.lights.allocated -eq 16
    removed = $samples.removed.modelLights -eq 0 -and $samples.removed.lights.allocated -eq 0
    waterMaterial = $samples.dark.water.faces -gt 0 -and $samples.dark.water.unlit -eq 0 -and $samples.wall.water.unlit -eq 0
    waterTorch = $samples.dark.water.modelLights -eq 0 -and $samples.wall.water.modelLights -ge 2 -and $samples.removed.water.modelLights -eq 0
    waterSingleSurface = $samples.dark.water.faces -eq 1 -and $samples.wall.water.faces -eq 1 -and $samples.dark.water.twoSided -eq 1
    waterTint = $tint.expected[2] -gt $tint.expected[0] -and $tint.expected[2] -gt $tint.expected[1] -and
        [Math]::Abs($tint.expected[0] - $tint.actual[0]) -lt .001 -and
        [Math]::Abs($tint.expected[1] - $tint.actual[1]) -lt .001 -and
        [Math]::Abs($tint.expected[2] - $tint.actual[2]) -lt .001
    enclosed = $samples.enclosed.exposure -eq 0 -and $samples.enclosed.modelLights -eq 0
    roomTorch = $samples.roomTorch.modelLights -gt 0 -and $minecraft.roomLight.roomTorch[1] -gt $minecraft.roomLight.enclosed[1]
    roomTorchPixels = $samples.roomTorch.luminance -gt ($samples.enclosed.luminance + 1)
    opened = $samples.opened.exposure -gt $samples.enclosed.exposure
    glassWindow = $samples.glass.exposure -gt $samples.enclosed.exposure -and $samples.glass.exposure -eq $samples.opened.exposure
    firstPersonCaster = $samples.floor.avatar.camera -eq 0 -and $samples.floor.avatar.vertices -gt 0
    sourceShadowDisabled = $samples.floor.avatar.sourceShadowDisabled
    avatarShadowDrawn = $samples.floor.shadows.avatar -gt 0
    blockShadowDrawn = $samples.floor.shadows.blocks -gt 0
    sourceEngineShadows = $samples.shadowOn.shadows.mode -eq 'source' -and $samples.shadowOn.shadows.native.installed -and
        $samples.shadowOn.shadows.native.castDraws -gt 0
    liveShadowResources = $samples.shadowOn.shadows.native.invalidMeshes -eq 0 -and
        $samples.shadowOn.shadows.native.staleEntities -eq 0 -and $samples.shadowOn.shadows.native.wrongThread -eq 0
    shadowPose = $samples.shadowOff.view -eq $samples.shadowOn.view -and $samples.shadowOff.angles -eq $samples.shadowOn.angles
    shadowGrid = $sameGrid
    shadowPixels = $darkenedPixels -gt 0
}
$results['shadowDarkenedPixels'] = $darkenedPixels
$results | ConvertTo-Json | Set-Content -LiteralPath "$destination\lighting-results.json"
$results
if ($results.Values -contains $false) { throw 'Lighting scenario failed. Read the paired artifacts.' }
