param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
foreach ($name in @('terrain-source', 'effects', 'world')) {
    Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-$name.json" -Destination $destination
}
$minecraft = Get-Content -Raw "$destination\terrain-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-terrain-source.json" | ConvertFrom-Json
$effects = Get-Content -Raw "$destination\garrycraft-effects.json" | ConvertFrom-Json
$world = Get-Content -Raw "$destination\garrycraft-world.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or $minecraft.request -ne $effects.request -or $minecraft.request -ne $world.terrainRequest) {
    throw 'Terrain and render traces refer to different scenarios.'
}
$results = [ordered]@{
    water = $minecraft.waterPassed
    fire = $minecraft.firePassed
    lava = $minecraft.lavaPassed
    placement = $minecraft.stonePassed
    removal = $minecraft.removed
    repeatedFireDamage = $source.burns.fire -gt 1 -and $source.health.fire.after -lt $source.health.fire.before
    repeatedLavaDamage = $source.burns.lava -gt 1 -and $source.health.lava.after -lt $source.health.lava.before
    cracksDrawn = $minecraft.crackVertices -gt 0 -and $effects.crackVerticesDrawn -gt 0
    debrisDrawn = $minecraft.debrisVertices -gt 0 -and $world.debrisVerticesDrawn -gt 0
}
$results | ConvertTo-Json | Set-Content -LiteralPath "$destination\terrain-results.json"
$results
if ($results.Values -contains $false) { throw 'Terrain scenario failed. Read the paired artifacts.' }
