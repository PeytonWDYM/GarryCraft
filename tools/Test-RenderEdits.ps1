param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$output = "$RunRoot/artifacts/render-edits"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item "$PSScriptRoot/../tests/render-edits.lua" "$data/garrycraft-render-edits.lua"
function Send($command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $command }
function Minecraft($command) { & "$PSScriptRoot/Send-MinecraftLabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $command }
function Capture($label) {
    Start-Sleep -Seconds 2
    Remove-Item -LiteralPath "$data/garrycraft-render-edits/$label.json", "$data/garrycraft-render-edits/$label.png" -ErrorAction SilentlyContinue
    Send "lua_run_cl GarryCraft.RenderEditTest.Capture('$label')"
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path "$data/garrycraft-render-edits/$label.json")) {
        if ([DateTime]::UtcNow -gt $deadline) { throw "No render capture: $label" }
        Start-Sleep -Milliseconds 100
    }
    Copy-Item "$data/garrycraft-render-edits/$label.*" $output -Force
}
Send 'sv_cheats 1'
Minecraft 'gamemode creative'
Minecraft 'tp @s 38 4 8'
Minecraft 'fill 36 2 0 39 2 3 minecraft:oak_log'
Minecraft 'fill 37 3 1 38 4 2 minecraft:oak_log'
Send "lua_run_cl RunString(file.Read('garrycraft-render-edits.lua','DATA')) GarryCraft.RenderEditTest.View()"
try {
    Capture 'tower'
    Send 'lua_run_cl GarryCraft.RenderEditTest.Begin()'
    Minecraft 'setblock 37 4 1 minecraft:air'
    Capture 'broken'
    Minecraft 'setblock 37 4 1 minecraft:oak_log'
    Capture 'replaced'
    Minecraft 'fill 47 2 0 48 2 0 minecraft:oak_log'
    Capture 'boundary-covered'
    Minecraft 'setblock 48 2 0 minecraft:air'
    Capture 'boundary-exposed'
    Minecraft 'setblock 40 2 0 minecraft:torch'
    Capture 'torch-on'
    Minecraft 'setblock 40 2 0 minecraft:air'
    Capture 'torch-off'
    Send 'lua_run_cl GarryCraft.RenderEditTest.Finish()'
    Start-Sleep -Milliseconds 200
    Copy-Item "$data/garrycraft-render-edits/transitions.json" $output -Force
} finally {
    Send "lua_run_cl hook.Remove('PostRender','GarryCraftRenderEditFrames')"
    Send 'lua_run_cl GarryCraft.RenderEditTest.RestoreView()'
    Minecraft 'fill 34 2 -1 48 4 3 minecraft:air'
}
$tower = Get-Content "$output/tower.json" -Raw | ConvertFrom-Json
$before = Get-Content "$output/boundary-covered.json" -Raw | ConvertFrom-Json
$after = Get-Content "$output/boundary-exposed.json" -Raw | ConvertFrom-Json
$transitions = Get-Content "$output/transitions.json" -Raw | ConvertFrom-Json
$broken = Get-Content "$output/broken.json" -Raw | ConvertFrom-Json
$replaced = Get-Content "$output/replaced.json" -Raw | ConvertFrom-Json
$torchOn = Get-Content "$output/torch-on.json" -Raw | ConvertFrom-Json
$torchOff = Get-Content "$output/torch-off.json" -Raw | ConvertFrom-Json
$retained = @($torchOff.faces | Where-Object {
    $offFace = $_
    @($torchOn.faces | Where-Object { $_.geometry -eq $offFace.geometry -and $_.model -eq $offFace.model }).Count -gt 0
})
$checks = [ordered]@{
    capturedFaces = $tower.faces.Count -gt 0
    sourceRenderer = $tower.blocks.renderer -eq 'source'
    removedCell = $tower.faces.Count -ne $broken.faces.Count -and
        (($tower.faces.geometry | Sort-Object) -join ',') -eq (($replaced.faces.geometry | Sort-Object) -join ',')
    boundaryFaceExposed = @($after.faces | Where-Object { $_.normal[0] -gt .99 -and [Math]::Abs($_.minimum[0]-1536) -lt .01 }).Count -eq 1
    transitionFrames = $transitions.frames.Count -gt 100
    torchGeometryChanged = $torchOn.blocks.vertices -gt $torchOff.blocks.vertices
    unchangedFacesRetained = $retained.Count -eq $torchOff.faces.Count
}
@{checks=$checks;passed=-not($checks.Values -contains $false)} | ConvertTo-Json | Set-Content "$output/result.json"
Get-Content "$output/result.json"
if ($checks.Values -contains $false) { throw 'Read the render edit captures.' }
