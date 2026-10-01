param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-lighting-source.json" -Destination $destination
$minecraft = Get-Content -Raw "$destination\lighting-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-lighting-source.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or -not $minecraft.completed) { throw 'Lighting traces describe different or incomplete scenarios.' }
$samples = $source.samples
$results = [ordered]@{
    dark = $samples.dark.modelLights -eq 0
    floor = $samples.floor.modelLights -gt 0 -and $samples.floor.lights.allocated -gt 0 -and $samples.floor.floorLight[0] -gt 0
    wall = $samples.wall.modelLights -ge 2 -and $samples.wall.lights.allocated -ge 2
    far = $samples.far.modelLights -eq $samples.wall.modelLights -and $samples.far.lights.allocated -ge 2
    budget = $samples.budget.lights.exported -gt 32 -and $samples.budget.lights.allocated -eq 16
    removed = $samples.removed.modelLights -eq 0 -and $samples.removed.lights.allocated -eq 0
}
$results | ConvertTo-Json | Set-Content -LiteralPath "$destination\lighting-results.json"
$results
if ($results.Values -contains $false) { throw 'Lighting scenario failed. Read the paired artifacts.' }
