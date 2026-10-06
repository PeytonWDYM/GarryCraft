param([Parameter(Mandatory)][string]$Config, [Parameter(Mandatory)][string]$DataPath,
    [Parameter(Mandatory)][int]$HostPid)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/RuntimeFiles.ps1"
. "$PSScriptRoot/RuntimeProcess.ps1"
$configuration = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$root = Split-Path -Parent $Config
$requestPath = Join-Path $DataPath 'garrycraft-runtime-request.json'
$statusPath = Join-Path $DataPath 'garrycraft-runtime-status.json'
$hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($root))).Replace('-', '')
$mutex = New-Object Threading.Mutex($false, "Local\GarryCraftRuntime-$hash")
try { $ownsRuntime = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsRuntime = $true }
if (-not $ownsRuntime) { $mutex.Dispose(); exit }
Start-Transcript -LiteralPath "$root/launcher-$HostPid.log" -Append | Out-Null
$client = $null
$control = $null
$currentMap = $null
$currentRequest = $null
$failedRequest = $null
$hostProcess = Get-Process -Id $HostPid
$hostStarted = $hostProcess.StartTime
$publishedStatus = $null
$request = $null
$requestWrittenAt = [DateTime]::MinValue

function Publish-Status($State, $Message) {
    $value = [ordered]@{id = $currentRequest; state = $State; message = $Message; map = $currentMap;
        hostPid = $HostPid; javaPid = $(if ($client) { $client.Id } else { 0 })}
    $json = $value | ConvertTo-Json -Compress
    if ($json -eq $publishedStatus) { return }
    # Status is advisory. A busy reader must not stop Minecraft or discard a pending update.
    if (Write-JsonFile $statusPath $value) { $script:publishedStatus = $json }
}
function Write-Control($Stop) {
    # Retain the world mutex while a control reader holds the previous file open.
    while (-not (Write-JsonFile $control @{stop = $Stop})) { Start-Sleep -Milliseconds 50 }
}
function Stop-Client([string]$Reason) {
    if (-not $client) { return }
    Write-Output "Stopping Minecraft PID $($client.Id) on ${currentMap}: $Reason"
    if (-not $client.HasExited) {
        Publish-Status 'saving' 'Saving the Minecraft world'
        Write-Control $true
        if (-not $client.WaitForExit(30000)) {
            # Do not kill Java during a world save or start a second writer.
            throw 'Minecraft has not finished saving. Read its log before restarting.'
        }
    }
    $client.WaitForExit() # Drain both output streams after the confirmed process exit.
    $client.Dispose()
    $script:client = $null
    $script:currentMap = $null
}

try {
    while ($true) {
        $hostProcess.Refresh()
        if ($hostProcess.HasExited -or $hostProcess.StartTime -ne $hostStarted) { break }
        if (Test-Path -LiteralPath $requestPath) {
            try {
                $nextRequest = Get-Content -LiteralPath $requestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($nextRequest) {
                    $nextWrittenAt = (Get-Item -LiteralPath $requestPath).LastWriteTime
                    $request = $nextRequest
                    $requestWrittenAt = $nextWrittenAt
                }
            } catch { }
        }
        # Source rewrites this file in place. Empty, partial, or locked reads retain
        # the last complete request. Failed reads cannot extend its heartbeat deadline.
        $fresh = $request -and ((Get-Date) - $requestWrittenAt).TotalSeconds -lt 120
        $wanted = $fresh -and $request.enabled
        if ($wanted -and ($request.map -match '[\\/:*?"<>|\x00]' -or $request.map -in '.', '..')) {
            throw 'The map name cannot be used as a world folder.'
        }
        if ($client -and (-not $wanted -or $currentMap -ne $request.map)) {
            if (-not $wanted) { $failedRequest = $currentRequest }
            $reason = if (-not $fresh) { 'Source heartbeat expired' } elseif (-not $request.enabled) { 'Source disabled the bridge' } else { "Map changed to $($request.map)" }
            Stop-Client $reason
        }
        if ($request) { $currentRequest = $request.id }
        if ($client -and $client.HasExited) {
            $failedRequest = $currentRequest
            $exitCode = $client.ExitCode
            Stop-Client "Process exited with code $exitCode"
            Publish-Status 'error' "Minecraft exited ($exitCode). Read the map's minecraft-stderr.log and crash-reports."
        }
        if ($wanted -and -not $client -and $failedRequest -ne $currentRequest) {
            $currentMap = $request.map
            $mapRoot = Join-Path $configuration.worlds $currentMap
            New-Item -ItemType Directory -Path "$mapRoot/minecraft", "$mapRoot/artifacts" -Force | Out-Null
            $control = Join-Path $mapRoot 'control.json'
            $readyPath = Join-Path $mapRoot 'ready.json'
            if (Test-Path -LiteralPath $readyPath) { Remove-Item -LiteralPath $readyPath }
            Write-Control $false
            # Clear mailboxes only after the previous owner has saved and exited.
            $bridge = Join-Path $mapRoot 'bridge.bin'
            [IO.File]::WriteAllBytes($bridge, (New-Object byte[] 134217728))
            $dynamicArgs = @("-Dgarrycraft.bridge=$(Get-RelativeRuntimePath $root $bridge)", "-Dgarrycraft.settings=$(Get-RelativeRuntimePath $root $configuration.settings)",
                "-Dgarrycraft.artifacts=$(Get-RelativeRuntimePath $root "$mapRoot/artifacts")", "-Dgarrycraft.control=$(Get-RelativeRuntimePath $root $control)")
            $argumentFile = Join-Path $mapRoot 'launch.args'
            $prefix = ($dynamicArgs | ForEach-Object { '"' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }) -join "`n"
            $encoding = [Text.Encoding]::GetEncoding([Text.Encoding]::Default.CodePage, (New-Object Text.EncoderExceptionFallback), (New-Object Text.DecoderExceptionFallback))
            $gameDirectory = (Get-RelativeRuntimePath $root "$mapRoot/minecraft").Replace('\', '\\').Replace('"', '\"')
            [IO.File]::WriteAllText($argumentFile, ($prefix + "`n" + [IO.File]::ReadAllText("$root/java.args") + "`n--gameDir`n`"$gameDirectory`"`n"), $encoding)
            $launchPath = Get-RelativeRuntimePath $root $argumentFile
            $client = [GarryCraftMinecraftProcess]::Start($configuration.java, "@`"$launchPath`"", $root, "$mapRoot/minecraft-stdout.log", "$mapRoot/minecraft-stderr.log")
            Publish-Status 'running' 'Waiting for Minecraft and map collision'
        }
        elseif ($wanted -and $client -and (Test-Path -LiteralPath $readyPath)) { Publish-Status 'ready' 'Minecraft is ready' }
        elseif (-not $wanted -and -not $client) { Publish-Status 'off' 'GarryCraft is off' }
        Start-Sleep -Milliseconds 500
    }
    Stop-Client 'Source host exited'
    Publish-Status 'off' 'GarryCraft is off'
} catch {
    Write-Output "Runtime failed: $($_.Exception.Message)"
    try { Publish-Status 'error' $_.Exception.Message }
    finally {
        if ($client -and -not $client.HasExited) {
            Write-Control $true
            $client.WaitForExit() # Keep the single-owner mutex until Java releases the world.
        }
    }
} finally {
    $hostProcess.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
