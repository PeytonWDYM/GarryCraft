param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($name in @('parity-source','render','world','blocks','frame-times')) {
    Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-$name.json" -Destination $destination
}
$minecraft = Get-Content -Raw "$destination\parity-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-parity-source.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or -not $source.completed) {
    throw 'The Source and Minecraft traces do not describe the same completed scenario.'
}
foreach ($name in @('minecraft-frame-times','garrycraft-frame-times')) {
    $report = Get-Content -Raw "$destination\$name.json" | ConvertFrom-Json
    Write-Output $name
    $report.summaries | ConvertTo-Json -Depth 4
}
