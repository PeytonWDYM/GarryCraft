param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [Parameter(Mandatory)][int]$GamePid, [switch]$AbruptExit)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/config.json")
$artifacts = Join-Path (Split-Path -Parent $RuntimeRoot) 'artifacts'
$checks = [ordered]@{}
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }
function Status { & "$PSScriptRoot/Read-JsonSnapshot.ps1" -Path "$LabPath/garrysmod/data/garrycraft-runtime-status.json" }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
$configuration = Get-Content "$RuntimeRoot/config.json" -Raw | ConvertFrom-Json
$worldRoot = $configuration.worlds.Replace('/', '\')
function Managed-Clients {
    @(Get-CimInstance Win32_Process -Filter "name='java.exe'" |
        Where-Object { $_.CommandLine.Replace('/', '\').Contains($worldRoot) })
}
try {
    Send 'garrycraft_disable'
    Wait-Until 'disabled runtime' { (Status).state -eq 'off' }
    $runtimeConfig = "$LabPath/garrysmod/data/garrycraft-runtime.json"
    $savedConfig = [IO.File]::ReadAllText($runtimeConfig)
    try {
        Remove-Item -LiteralPath $runtimeConfig
        Send 'garrycraft_enable'
        Start-Sleep -Seconds 1
        $probe = "$LabPath/garrysmod/data/garrycraft-lifecycle-missing.json"
        if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe }
        Send "lua_run file.Write('garrycraft-lifecycle-missing.json',util.TableToJSON({active=GarryCraft.IsActive(),message=GetGlobalString('GarryCraftStatus')}))"
        Wait-Until 'missing configuration report' { Test-Path -LiteralPath $probe }
        Copy-Item -LiteralPath $probe -Destination $artifacts
        $report = Get-Content -LiteralPath $probe -Raw | ConvertFrom-Json
        $checks.missingConfiguration = -not $report.active -and $report.message.Contains('Install.cmd')
    } finally { [IO.File]::WriteAllText($runtimeConfig, $savedConfig) }
    Send 'garrycraft_disable'
    Send 'garrycraft_enable'
    Wait-Until 'Minecraft startup' { (Status).state -eq 'running' -and (Status).hostPid -eq $GamePid }
    Send 'disconnect'
    Wait-Until 'save after startup disconnect' { (Status).state -eq 'off' -and (Managed-Clients).Count -eq 0 }
    $checks.startupDisconnect = $true
    Send 'map gm_construct'
    Wait-Until 'automatic startup after reconnect' {
        $status = Status
        if ($status.state -ne 'ready') { return $false }
        $state = & "$PSScriptRoot/Observe.ps1" -Bridge "$RuntimeRoot/worlds/gm_construct/bridge.bin"
        $state.linked -and $state.geometryReady
    }
    $checks.automaticReconnect = $true
    $clientPid = (Status).javaPid
    if ($AbruptExit) { Stop-Process -Id $GamePid }
    else { Send 'quit' }
    Wait-Until 'Source exit' { -not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue) }
    Wait-Until 'Minecraft exit after Source' { (Managed-Clients).Count -eq 0 -and (Status).state -eq 'off' }
    $checks.hostExit = $true
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; hostPid=$GamePid; lastJavaPid=$clientPid; abruptExit=[bool]$AbruptExit} |
        ConvertTo-Json -Depth 6 | Set-Content "$artifacts/lifecycle-result.json"
    if (-not $passed) { throw 'Lifecycle checks failed. Read lifecycle-result.json.' }
    Get-Content "$artifacts/lifecycle-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message} |
        ConvertTo-Json -Depth 6 | Set-Content "$artifacts/lifecycle-result.json"
    throw
}
