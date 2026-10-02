param([Parameter(Mandatory)][string]$RunRoot, [Parameter(Mandatory)][string]$LabPath)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Gameplay collection requires the owned Source lab.' }
$artifacts = "$RunRoot/artifacts"
$minecraft = Get-Content -LiteralPath "$artifacts/polish-minecraft.json" -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath "$LabPath/garrysmod/data/garrycraft-render.json" -Raw | ConvertFrom-Json
$checks = [ordered]@{
    pairedRequest = $minecraft.request -eq $source.polishRequest
    completed = $minecraft.completed
    golemWandered = $minecraft.mobTravel[0] -gt 1
    villagerWandered = $minecraft.mobTravel[1] -gt 1
    cowWandered = $minecraft.mobTravel[2] -gt 1
    enchantedArmor = $minecraft.avatarVertices.'plain-armor' -gt 0 -and $minecraft.avatarVertices.'enchanted-armor' -eq $minecraft.avatarVertices.'plain-armor'
    rearArmor = $minecraft.avatarVertices.'rear-armor' -eq $minecraft.avatarVertices.'plain-armor'
    waterRemains = $minecraft.sourceWater
    nativeWallDry = $minecraft.nativeWallDry
    animatedSprites = @($minecraft.textureFrames.psobject.Properties | Where-Object Value -ge 16).Count -ge 2
    sourceReceivedAnimation = @($source.textureUpdates | Where-Object { $_ -gt 16 }).Count -ge 2
}
Copy-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-render.json" -Destination "$artifacts/polish-source.json"
$passed = -not ($checks.Values -contains $false)
@{passed=$passed;request=$minecraft.request;checks=$checks} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath "$artifacts/polish-result.json"
Get-Content -LiteralPath "$artifacts/polish-result.json"
if (-not $passed) { throw 'Gameplay checks failed. Read the paired gameplay traces.' }
