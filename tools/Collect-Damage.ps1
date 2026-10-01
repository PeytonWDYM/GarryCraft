param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-damage-source.json" -Destination $destination
$minecraft = Get-Content -Raw "$destination\damage-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-damage-source.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request) { throw 'Damage traces refer to different scenarios.' }
$results = @($minecraft.hits)
$rows = $source.trace
$initial = ($rows | Where-Object phase -eq 'prepare' | Select-Object -Last 1).npcHealth
$afterPlayer = ($rows | Where-Object phase -eq 'player-source' | Select-Object -Last 1).npcHealth
$afterMob = ($rows | Where-Object phase -eq 'mob-source' | Select-Object -Last 1).npcHealth
$playerSource = $initial - $afterPlayer
$mobSource = $afterPlayer - $afterMob
foreach ($comparison in @(
    @('player-source', $source.expected.playerDamage, $playerSource),
    @('mob-source', $source.expected.mobDamage, $mobSource),
    @('source-player', $source.expected.sourcePlayer, $minecraft.nativeDamage.'source-player'),
    @('source-mob', $source.expected.sourceMob, $minecraft.nativeDamage.'source-mob')
)) {
    $results += [pscustomobject]@{direction=$comparison[0]; expected=$comparison[1]; actual=$comparison[2]; passed=[Math]::Abs($comparison[1]-$comparison[2]) -lt .001}
}
$results | ConvertTo-Json | Set-Content -LiteralPath "$destination\damage-results.json"
$results | Format-Table direction, expected, actual, passed
if ($results.Count -ne 8 -or ($results | Where-Object { -not $_.passed })) { throw 'Damage scaling scenario failed. Read the paired artifacts.' }
