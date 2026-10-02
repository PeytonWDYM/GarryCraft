param([Parameter(Mandatory)][string]$RunRoot, [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab")
$ErrorActionPreference = 'Stop'
$destination = Join-Path $RunRoot 'artifacts'
foreach ($name in @('responsiveness-source', 'render', 'frame-times')) {
    Copy-Item -LiteralPath "$LabPath\garrysmod\data\garrycraft-$name.json" -Destination $destination
}
$minecraft = Get-Content -Raw "$destination\responsiveness-minecraft.json" | ConvertFrom-Json
$source = Get-Content -Raw "$destination\garrycraft-responsiveness-source.json" | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or -not $minecraft.completed -or -not $source.completed) {
    throw 'Responsiveness traces describe different or incomplete scenarios.'
}
$ages = @($minecraft.inputAgesMs | Sort-Object)
if ($ages.Count -lt 100) { throw 'Too few client input samples.' }
$inputP99 = $ages[[Math]::Ceiling($ages.Count * .99) - 1]
$checks = [ordered]@{
    videoScroll = $minecraft.videoScroll -gt 0
    creativeSearchScroll = $minecraft.creativeScroll -gt 0
    continuousYaw = $minecraft.maxYawStep -lt 30
    tutorialDisabled = $minecraft.tutorialDisabled
    inputDelivery = $inputP99 -lt 25
}
$overlay = @($source.overlayAgesMs | Sort-Object)
$report = [ordered]@{request = $minecraft.request; checks = $checks; inputP99Ms = $inputP99}
if ($overlay.Count) { $report.overlayP99Ms = $overlay[[Math]::Ceiling($overlay.Count * .99) - 1] }
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$destination\responsiveness-results.json"
$report
if ($checks.Values -contains $false) { throw 'Responsiveness scenario failed. Read the paired artifacts.' }
