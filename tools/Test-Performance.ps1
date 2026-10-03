param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot, [int[]]$PropCounts = @(0, 32, 96, 192), [int]$Seconds = 12)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts/performance"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot/../tests/performance.lua" -Destination "$data/garrycraft-performance-fixture.lua"
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function State { & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin" }
function Summary($Values) {
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return @{count = 0} }
    return @{count = $sorted.Count; p50 = $sorted[[Math]::Ceiling($sorted.Count * .5) - 1];
        p95 = $sorted[[Math]::Ceiling($sorted.Count * .95) - 1]; p99 = $sorted[[Math]::Ceiling($sorted.Count * .99) - 1];
        maximum = $sorted[-1]; over16ms = @($sorted | Where-Object { $_ -gt 16.667 }).Count}
}
$results = @()
Send 'lua_run RunString(file.Read("garrycraft-performance-fixture.lua","DATA"))'
try {
    foreach ($count in $PropCounts) {
        $label = "props-$count"
        Send "lua_run GarryCraft.PerformanceTest.Begin($count,'$label')"
        Start-Sleep -Seconds 3
        Send 'garrycraft_fps_reset'
        Start-Sleep -Seconds $Seconds
        Send 'garrycraft_frame_report'
        Send 'lua_run GarryCraft.PerformanceTest.Report()'
        Send 'garrycraft_render_report'
        Start-Sleep -Milliseconds 500
        $phase = "$artifacts/$label"
        New-Item -ItemType Directory -Path $phase -Force | Out-Null
        foreach ($name in 'garrycraft-frame-times.json', 'garrycraft-performance.json', 'garrycraft-render.json') {
            Copy-Item -LiteralPath "$data/$name" -Destination "$phase/$name"
        }
        $state = State
        $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath "$phase/minecraft.json" -Encoding utf8NoBOM
        $frame = Get-Content -LiteralPath "$phase/garrycraft-frame-times.json" -Raw | ConvertFrom-Json
        $fixture = Get-Content -LiteralPath "$phase/garrycraft-performance.json" -Raw | ConvertFrom-Json
        $stages = @{}
        foreach ($stage in 'query', 'instances', 'water', 'actors', 'json', 'pack') {
            $field = $stage + 'Milliseconds'
            $stages[$stage] = Summary @($fixture.geometry | ForEach-Object { $_.stages.$field })
        }
        $results += @{phase = $label; props = $fixture.props; awake = $fixture.awake; linked = $state.linked;
            source = Summary $frame.frames; geometry = Summary $fixture.geometry.ms;
            geometryStages = $stages; backend = $fixture.backend; nativeGeometry = $fixture.nativeGeometry}
    }
} finally {
    Send 'lua_run GarryCraft.PerformanceTest.Stop()'
}
$passed = @($results | Where-Object { -not $_.linked -or $_.awake -ne $_.props -or $_.source.count -lt 100 }).Count -eq 0
@{passed = $passed; seconds = $Seconds; phases = $results} | ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath "$artifacts/result.json" -Encoding utf8NoBOM
Get-Content -LiteralPath "$artifacts/result.json"
if (-not $passed) { throw 'Performance fixture failed. Read artifacts/performance/result.json.' }
