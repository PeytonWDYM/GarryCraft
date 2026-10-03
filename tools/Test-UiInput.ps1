param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
$LabPath = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/.garrycraft-lab")
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/bridge.bin")
$data = "$LabPath/garrysmod/data"
$artifacts = "$RunRoot/artifacts"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$game = Get-Process -Id $GamePid
function Send($Command) { & "$PSScriptRoot/Send-LabCommand.ps1" -GamePid $GamePid -LabPath $LabPath -Command $Command }

. "$PSScriptRoot/SourceInput.ps1"
try {
Copy-Item "$PSScriptRoot/../tests/ui-input.lua" "$data/garrycraft-ui-input-fixture.lua"
$request = 'responsiveness:ui-input:' + [Guid]::NewGuid().ToString('N')
$readyFile = "$data/garrycraft-ui-input-ready.json"
Send "lua_run_cl hook.Remove('Think','GarryCraftUiInputFixture') timer.Remove('GarryCraftUiInputAwaitRequest')"
foreach ($file in @("$data/garrycraft-ui-input-source.json", $readyFile, "$artifacts/ui-input-live.json", "$artifacts/ui-input-minecraft.json")) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
}
[GarryCraftSourceInput]::Focus($game.MainWindowHandle)
# The previous completed request can remain in lane 1. Load the observer only after Source accepts this request.
Send "lua_run_cl timer.Create('GarryCraftUiInputAwaitRequest',0.01,1000,function() local s=GarryCraft.State if s and s.responsivenessRequest=='$request' then timer.Remove('GarryCraftUiInputAwaitRequest') RunString(file.Read('garrycraft-ui-input-fixture.lua','DATA')) file.Write('garrycraft-ui-input-ready.json',util.TableToJSON({request=s.responsivenessRequest,phase=s.responsivenessPhase})) end end)"
Send "lua_run GarryCraft.BeginTest(player.GetHumans()[1], '$request')"
$readyDeadline = [DateTime]::UtcNow.AddSeconds(10)
$ready = $null
do {
    if (Test-Path -LiteralPath $readyFile) {
        try { $ready = Get-Content -LiteralPath $readyFile -Raw | ConvertFrom-Json } catch { $ready = $null }
    }
    if ($ready -and $ready.request -eq $request) { break }
    Start-Sleep -Milliseconds 25
} while ([DateTime]::UtcNow -lt $readyDeadline)
if (-not $ready -or $ready.request -ne $request) { throw 'Source did not observe the current UI input request.' }
if ($ready.phase -ne 'creative-search') { throw 'The UI observer started after the first input phase.' }
$handled = @{}
$actions = @()
$deadline = [DateTime]::UtcNow.AddSeconds(90)
do {
    $liveFile = "$artifacts/ui-input-live.json"
    if (Test-Path -LiteralPath $liveFile) {
        try { $live = Get-Content -LiteralPath $liveFile -Raw | ConvertFrom-Json } catch { $live = $null }
        if ($live -and $live.request -eq $request -and -not $handled.ContainsKey($live.phase)) {
            $handled[$live.phase] = $true
            Start-Sleep -Milliseconds 400
            [GarryCraftSourceInput]::Focus($game.MainWindowHandle)
            switch ($live.phase) {
                'creative-search' { [GarryCraftSourceInput]::Click($live.mouseX, $live.mouseY); [GarryCraftSourceInput]::Text('diamond') }
                'creative-reopen' { [GarryCraftSourceInput]::Click($live.mouseX, $live.mouseY); [GarryCraftSourceInput]::Text('stone') }
                'chat-completion' {
                    [GarryCraftSourceInput]::Text('/time set ')
                    Start-Sleep -Milliseconds 500
                    [GarryCraftSourceInput]::Key(9)
                    Start-Sleep -Milliseconds 350
                    [GarryCraftSourceInput]::Key(9)
                    Start-Sleep -Milliseconds 350
                    [GarryCraftSourceInput]::Text(' ')
                    Start-Sleep -Milliseconds 350
                    [GarryCraftSourceInput]::Key(13)
                }
                'chat-reopen' {
                    [GarryCraftSourceInput]::Text('garrycraft_ui_reopen')
                    Start-Sleep -Milliseconds 400
                    [GarryCraftSourceInput]::Key(13)
                }
            }
            $actions += @{phase = $live.phase; time = [DateTime]::UtcNow.ToString('o')}
        }
        if ($live -and $live.request -eq $request -and $live.phase -eq 'done') { break }
    }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)
if (-not $live -or $live.request -ne $request -or $live.phase -ne 'done') { throw 'The UI input scenario did not finish.' }
Start-Sleep -Milliseconds 500
Copy-Item "$data/garrycraft-ui-input-source.json" -Destination $artifacts
$minecraft = Get-Content "$artifacts/ui-input-minecraft.json" -Raw | ConvertFrom-Json
$source = Get-Content "$artifacts/garrycraft-ui-input-source.json" -Raw | ConvertFrom-Json
if ($minecraft.request -ne $request -or $source.request -ne $request -or -not $minecraft.completed -or -not $source.completed) {
    throw 'UI input traces describe different or incomplete scenarios.'
}
$samples = $minecraft.samples
$creative = @($samples | Where-Object { $_.phase -eq 'creative-search' -and $_.search -eq 'diamond' })
$reopened = @($samples | Where-Object { $_.phase -eq 'creative-reopen' -and $_.search -eq 'stone' })
$chat = @($samples | Where-Object { $_.phase -eq 'chat-completion' -and $_.chat.StartsWith('/time set ') })
$completions = @($chat.chat | Where-Object { $_ -ne '/time set ' -and -not $_.EndsWith(' ') } | Select-Object -Unique)
$tabs = @($source.callbacks | Where-Object { $_.phase -eq 'chat-completion' -and $_.kind -eq 'key' -and $_.code -eq $source.tabKey })
$submitted = @($minecraft.recentChat | Where-Object { $_.StartsWith('/time set ') -and $_ -ne '/time set ' })[-1]
$commandExecuted = $false
if ($submitted) {
    $word = $submitted.Trim().Split(' ')[-1].Split(':')[-1]
    $targetTime = @{day = 1000; midnight = 18000; night = 13000; noon = 6000}[$word]
    $commandExecuted = $null -ne $targetTime -and @($samples | Where-Object {
        $_.phase -eq 'chat-completion' -and $_.screen -eq 'none' -and
        $_.dayTime % 24000 -ge $targetTime -and $_.dayTime % 24000 -lt $targetTime + 400
    }).Count -gt 0
}
$checks = [ordered]@{
    actualCreativeClicks = @($source.callbacks | Where-Object {
        $_.phase -in @('creative-search', 'creative-reopen') -and $_.kind -eq 'mouse' -and
        $_.code -eq $source.mouseLeftKey -and -not $_.down
    }).Count -eq 2
    creativeRealText = $creative.Count -gt 0
    creativeFiltered = @($creative | Where-Object { $_.items -gt 0 -and $_.items -lt $_.allItems -and $_.matchingItems -eq $_.items }).Count -gt 0
    creativeReopenRealText = $reopened.Count -gt 0
    twoRealTabCallbacks = $tabs.Count -eq 2 -and @($tabs | Where-Object { -not $_.focused }).Count -eq 0
    completionCycles = $completions.Count -ge 2
    typingAfterTabs = @($chat | Where-Object { $_.chat -ne '/time set ' -and $_.chat.EndsWith(' ') }).Count -gt 0
    enterAfterTabs = @($samples | Where-Object { $_.phase -eq 'chat-completion' -and $_.screen -eq 'none' }).Count -gt 0
    commandExecuted = $commandExecuted
    chatReopenTyping = @($samples | Where-Object { $_.phase -eq 'chat-reopen' -and $_.chat -eq 'garrycraft_ui_reopen' }).Count -gt 0
    chatReopenEnter = $minecraft.recentChat -contains 'garrycraft_ui_reopen'
    actualVguiTextCallbacks = @($source.callbacks | Where-Object { $_.kind -eq 'text' -and $_.focused }).Count -ge 30
    sourceScreenClosed = @($source.trace | Where-Object { $_.phase -eq 'creative-close' -and -not $_.screenOpen -and -not $_.hasPanel }).Count -gt 0
}
$passed = -not ($checks.Values -contains $false)
@{passed = $passed; checks = $checks; request = $minecraft.request; actions = $actions;
    inputMethod = 'Windows SendInput into the owned GMod window'} | ConvertTo-Json -Depth 8 |
    Set-Content "$artifacts/ui-input-result.json"
Get-Content "$artifacts/ui-input-result.json"
if (-not $passed) { throw 'UI input checks failed. Read the paired UI input artifacts.' }
} finally {
    [GarryCraftSourceInput]::Release() | Out-Null
}
