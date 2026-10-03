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

# Send physical keyboard events to the owned Source window, including its real VGUI focus traversal.
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
public static class GarryCraftUiInputTest {
    [StructLayout(LayoutKind.Sequential)] struct Keyboard { public ushort key, scan; public uint flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct Mouse { public int x, y; public uint data, flags, time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] struct Payload { [FieldOffset(0)] public Keyboard keyboard; [FieldOffset(0)] public Mouse mouse; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public uint type; public Payload payload; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left, top, right, bottom; }
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint count, Input[] inputs, int size);
    static IntPtr target;
    public static void Focus(IntPtr window) {
        target = window;
        SetForegroundWindow(window);
        Thread.Sleep(200);
        RequireFocus();
    }
    static void RequireFocus() {
        if (GetForegroundWindow() != target) throw new InvalidOperationException("The owned Source window must have keyboard focus.");
    }
    static void Dispatch(Input input) {
        RequireFocus();
        if (SendInput(1, new[] { input }, Marshal.SizeOf<Input>()) != 1)
            throw new InvalidOperationException("Windows did not accept the Source input event.");
    }
    public static void Key(ushort key) {
        Dispatch(new Input { type = 1, payload = new Payload { keyboard = new Keyboard { key = key } } });
        Thread.Sleep(60);
        Dispatch(new Input { type = 1, payload = new Payload { keyboard = new Keyboard { key = key, flags = 2 } } });
        Thread.Sleep(120);
    }
    public static void Text(string text) {
        foreach (char character in text) {
            short mapping = VkKeyScan(character);
            if (mapping == -1) throw new InvalidOperationException("The test text has no keyboard mapping.");
            bool shift = (mapping & 0x100) != 0;
            if (shift) Dispatch(new Input { type = 1, payload = new Payload { keyboard = new Keyboard { key = 0x10 } } });
            Key((ushort)(mapping & 0xff));
            if (shift) Dispatch(new Input { type = 1, payload = new Payload { keyboard = new Keyboard { key = 0x10, flags = 2 } } });
        }
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern short VkKeyScan(char character);
    public static void Click(double x, double y) {
        RequireFocus();
        GetClientRect(target, out Rect rect);
        var point = new Point { x = (int)((rect.right - rect.left) * x), y = (int)((rect.bottom - rect.top) * y) };
        ClientToScreen(target, ref point);
        SetCursorPos(point.x, point.y);
        Thread.Sleep(100);
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { flags = 2 } } });
        Thread.Sleep(60);
        Dispatch(new Input { type = 0, payload = new Payload { mouse = new Mouse { flags = 4 } } });
        Thread.Sleep(200);
    }
}
'@
Copy-Item "$PSScriptRoot/../tests/ui-input.lua" "$data/garrycraft-ui-input-fixture.lua"
foreach ($file in @("$data/garrycraft-ui-input-source.json", "$artifacts/ui-input-live.json", "$artifacts/ui-input-minecraft.json")) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
}
Send "lua_run_cl RunString(file.Read('garrycraft-ui-input-fixture.lua','DATA'))"
[GarryCraftUiInputTest]::Focus($game.MainWindowHandle)
Send "lua_run GarryCraft.BeginTest(player.GetHumans()[1], 'responsiveness:ui-input:' .. tostring(SysTime()))"
$handled = @{}
$actions = @()
$deadline = [DateTime]::UtcNow.AddSeconds(90)
do {
    $liveFile = "$artifacts/ui-input-live.json"
    if (Test-Path -LiteralPath $liveFile) {
        try { $live = Get-Content -LiteralPath $liveFile -Raw | ConvertFrom-Json } catch { $live = $null }
        if ($live -and -not $handled.ContainsKey($live.phase)) {
            $handled[$live.phase] = $true
            Start-Sleep -Milliseconds 400
            switch ($live.phase) {
                'creative-search' { [GarryCraftUiInputTest]::Click($live.mouseX, $live.mouseY); [GarryCraftUiInputTest]::Text('diamond') }
                'creative-reopen' { [GarryCraftUiInputTest]::Click($live.mouseX, $live.mouseY); [GarryCraftUiInputTest]::Text('stone') }
                'chat-completion' {
                    [GarryCraftUiInputTest]::Text('/time set ')
                    Start-Sleep -Milliseconds 500
                    [GarryCraftUiInputTest]::Key(9)
                    Start-Sleep -Milliseconds 350
                    [GarryCraftUiInputTest]::Key(9)
                    Start-Sleep -Milliseconds 350
                    [GarryCraftUiInputTest]::Text(' ')
                    Start-Sleep -Milliseconds 350
                    [GarryCraftUiInputTest]::Key(13)
                }
                'chat-reopen' {
                    [GarryCraftUiInputTest]::Text('garrycraft_ui_reopen')
                    Start-Sleep -Milliseconds 400
                    [GarryCraftUiInputTest]::Key(13)
                }
            }
            $actions += @{phase = $live.phase; time = [DateTime]::UtcNow.ToString('o')}
        }
        if ($live -and $live.phase -eq 'done') { break }
    }
    Start-Sleep -Milliseconds 100
} while ([DateTime]::UtcNow -lt $deadline)
if (-not $live -or $live.phase -ne 'done') { throw 'The UI input scenario did not finish.' }
Start-Sleep -Milliseconds 500
Copy-Item "$data/garrycraft-ui-input-source.json" -Destination $artifacts
$minecraft = Get-Content "$artifacts/ui-input-minecraft.json" -Raw | ConvertFrom-Json
$source = Get-Content "$artifacts/garrycraft-ui-input-source.json" -Raw | ConvertFrom-Json
if ($minecraft.request -ne $source.request -or -not $minecraft.completed -or -not $source.completed) {
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
