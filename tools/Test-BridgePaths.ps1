param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/bridge.bin")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$checks = [ordered]@{}
$samples = @()
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
function Snapshot($Name) {
    $filename = "garrycraft-path-$Name.json"
    if (Test-Path "$data/$filename") { Remove-Item -LiteralPath "$data/$filename" }
    Send "lua_run file.Write('$filename',util.TableToJSON({active=GarryCraft.IsActive(),linked=GarryCraft.IsLinked(),session=player.GetHumans()[1]:GetNWString('GarryCraftSession'),bridge=GetConVar('garrycraft_bridge'):GetString(),pending=file.Exists('garrycraft-control.json','DATA')}))"
    Wait-Until "snapshot $Name" { Test-Path "$data/$filename" }
    Copy-Item "$data/$filename" -Destination $artifacts
    $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin"
    $state | ConvertTo-Json -Depth 12 | Set-Content "$artifacts/minecraft-$Name.json"
    $script:samples += @{instance=$state.instance; session=$state.session; frame=$state.frame;
        linked=$state.linked; geometryReady=$state.geometryReady}
    Get-Content "$data/$filename" -Raw | ConvertFrom-Json
}
function Wait-Linked {
    Wait-Until 'both games linked' {
        $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RunRoot/bridge.bin"
        $state.linked -and $state.geometryReady
    }
}
try {
    Wait-Linked
    $before = Snapshot 'initial'
    $checks.physicalPath = $before.bridge.Replace('/', '\') -eq "$RunRoot\bridge.bin"
    $checks.initialRequestConsumed = -not $before.pending
    @{id=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); command='start'; bridge="$RunRoot/bridge.bin".Replace('\', '/')} |
        ConvertTo-Json -Compress | Set-Content "$data/garrycraft-control.json" -Encoding utf8NoBOM
    Start-Sleep -Seconds 2
    Wait-Linked
    $fresh = Snapshot 'fresh'
    $checks.freshRequestApplied = $fresh.active -and $fresh.linked -and $fresh.session -ne $before.session
    $checks.freshRequestConsumed = -not $fresh.pending
    # A new Lua state must not replay a completed request after map entry.
    Send 'lua_run GarryCraft.ControlRequest=nil include("garrycraft/sv_lab.lua")'
    Start-Sleep -Seconds 2
    $reload = Snapshot 'reload'
    $checks.noReplay = $reload.active -and $reload.linked -and $reload.session -eq $fresh.session
    $checks.sameMinecraft = $samples[0].instance -eq $samples[-1].instance
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; sourcePid=$GamePid; samples=$samples} |
        ConvertTo-Json -Depth 12 | Set-Content "$artifacts/bridge-path-result.json"
    Get-Content "$artifacts/bridge-path-result.json"
    if (-not $passed) { throw 'Bridge path checks failed. Read bridge-path-result.json.' }
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; samples=$samples} |
        ConvertTo-Json -Depth 12 | Set-Content "$artifacts/bridge-path-result.json"
    throw
}
