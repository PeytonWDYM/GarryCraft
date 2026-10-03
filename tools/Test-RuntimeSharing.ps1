param([Parameter(Mandatory)][string]$RuntimeRoot,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/runtime-sharing/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/config.json")
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new owned run directory for this test.' }
New-Item -ItemType Directory -Path "$RunRoot/data", "$RunRoot/settings" -Force | Out-Null
[IO.File]::WriteAllText("$RunRoot/owner", 'runtime-sharing')
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/owner")
Copy-Item "$RuntimeRoot/java.args" "$RunRoot/java.args"
Copy-Item "$PSScriptRoot/Runtime.ps1" "$RunRoot/Runtime.ps1"
Copy-Item "$PSScriptRoot/RuntimeFiles.ps1" "$RunRoot/RuntimeFiles.ps1"
$configuration = Get-Content "$RuntimeRoot/config.json" -Raw | ConvertFrom-Json
@{java=$configuration.java; settings="$RunRoot/settings"; worlds="$RunRoot/worlds"} |
    ConvertTo-Json | Set-Content "$RunRoot/config.json" -Encoding utf8NoBOM
"maxFps:60`nenableVsync:false`npauseOnLostFocus:false`nautoJump:false`n" |
    Set-Content "$RunRoot/settings/options.txt" -Encoding utf8NoBOM
$requestPath = "$RunRoot/data/garrycraft-runtime-request.json"
$statusPath = "$RunRoot/data/garrycraft-runtime-status.json"
$mapRoot = "$RunRoot/worlds/sharing_fixture"
$checks = [ordered]@{}
$helper = $null
$statusReader = $null
$controlReader = $null
$clientPid = 0
function Request($Enabled) {
    @{id='sharing-fixture'; map='sharing_fixture'; enabled=$Enabled} |
        ConvertTo-Json -Compress | Set-Content $requestPath -Encoding utf8NoBOM
}
function Status { & "$PSScriptRoot/Read-JsonSnapshot.ps1" -Path $statusPath }
function Wait-Until($Description, [scriptblock]$Condition) {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out: $Description"
}
try {
    Request $true
    $arguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$RunRoot/Runtime.ps1`"",
        '-Config', "`"$RunRoot/config.json`"", '-DataPath', "`"$RunRoot/data`"", '-HostPid', $PID)
    $helper = Start-Process "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru
    Wait-Until 'Java startup' { (Test-Path $statusPath) -and (Status).state -eq 'running' }
    $clientPid = (Status).javaPid
    # Source's reader can deny replacement while it reads a status snapshot.
    $statusReader = [IO.FileStream]::new($statusPath, 'Open', 'Read', 'ReadWrite')
    Wait-Until 'Minecraft world ready' { Test-Path "$mapRoot/ready.json" }
    Start-Sleep -Seconds 5
    $checks.readerDoesNotStopLauncher = -not $helper.HasExited
    $checks.readerDoesNotStopMinecraft = [bool](Get-Process -Id $clientPid -ErrorAction SilentlyContinue)
    $checks.lockedStatusValid = (Status).state -eq 'running'
    $statusReader.Dispose(); $statusReader = $null
    Wait-Until 'deferred ready status' { (Status).state -eq 'ready' }
    $checks.sameClientAfterUnlock = (Status).javaPid -eq $clientPid
    $written = [IO.File]::GetLastWriteTimeUtc($statusPath)
    Start-Sleep -Seconds 3
    $checks.unchangedStatusNotRewritten = [IO.File]::GetLastWriteTimeUtc($statusPath) -eq $written
    $controlReader = [IO.FileStream]::new("$mapRoot/control.json", 'Open', 'Read', 'ReadWrite')
    Request $false
    Wait-Until 'pending save' { (Status).state -eq 'saving' }
    Start-Sleep -Seconds 2
    $checks.shutdownRetainsOwnership = -not $helper.HasExited -and [bool](Get-Process -Id $clientPid -ErrorAction SilentlyContinue)
    $controlReader.Dispose(); $controlReader = $null
    Wait-Until 'Minecraft save and exit' { (Status).state -eq 'off' -and -not (Get-Process -Id $clientPid -ErrorAction SilentlyContinue) }
    $checks.cleanExit = $true
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; javaPid=$clientPid; launcherPid=$helper.Id; directory=$RunRoot} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/runtime-sharing-result.json"
    if (-not $passed) { throw 'Runtime sharing checks failed. Read runtime-sharing-result.json.' }
    Get-Content "$RunRoot/runtime-sharing-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; javaPid=$clientPid} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/runtime-sharing-result.json"
    throw
} finally {
    if ($statusReader) { $statusReader.Dispose() }
    if ($controlReader) { $controlReader.Dispose() }
    Request $false
    if ($clientPid -and (Get-Process -Id $clientPid -ErrorAction SilentlyContinue)) {
        [IO.File]::WriteAllText("$mapRoot/control.json", '{"stop":true}')
        Wait-Until 'test cleanup save' { -not (Get-Process -Id $clientPid -ErrorAction SilentlyContinue) }
    }
    if ($helper) { $helper.Dispose() }
}
