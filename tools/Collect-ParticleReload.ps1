param([Parameter(Mandatory)][string]$RunRoot, [Parameter(Mandatory)][string]$LabPath)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Particle reload collection requires the owned Source lab.' }
$artifacts = "$RunRoot/artifacts"
Copy-Item -LiteralPath "$LabPath/garrysmod/data/garrycraft-particle-reload-source.json" -Destination "$artifacts/particle-reload-source.json"
$minecraft = Get-Content -LiteralPath "$artifacts/particle-reload-minecraft.json" -Raw | ConvertFrom-Json
$source = Get-Content -LiteralPath "$artifacts/particle-reload-source.json" -Raw | ConvertFrom-Json
$checks = [ordered]@{
    pairedRequest = $minecraft.request -eq $source.request
    completed = $minecraft.completed -and $source.completed
    atlasChanged = $minecraft.oldWidth -ne $minecraft.newWidth -or $minecraft.oldHeight -ne $minecraft.newHeight -or
        $minecraft.oldWidth -ne $minecraft.restoredWidth -or $minecraft.oldHeight -ne $minecraft.restoredHeight
    minecraftBefore = $minecraft.beforeVertices -gt 0
    minecraftAfter = $minecraft.afterVertices -gt 0
    sourceBefore = $source.beforeVertices -gt 0
    sourceAfter = $source.afterVertices -gt 0
    vanillaClearedParticles = $minecraft.afterReloadParticles -eq 'T 0'
    restoredOptions = $minecraft.mipmapsRestored
}
$passed = -not ($checks.Values -contains $false)
@{passed=$passed; request=$minecraft.request; checks=$checks} | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath "$artifacts/particle-reload-result.json"
Get-Content -LiteralPath "$artifacts/particle-reload-result.json"
if (-not $passed) { throw 'Particle reload checks failed. Read the paired traces.' }
