param(
    [Parameter(Mandatory)][string]$RunRoot,
    [string]$LabPath = "$env:LOCALAPPDATA\GarryCraft\gmod-lab",
    [switch]$Screenshots
)
$ErrorActionPreference = 'Stop'
$executable = [IO.Path]::GetFullPath("$LabPath\bin\win64\gmod.exe")
if (-not (Test-Path -LiteralPath "$LabPath\.garrycraft-lab")) { throw 'Resolution tests require an isolated lab installation.' }
$owned = @(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -eq $executable } |
    ForEach-Object { Get-Process -Id $_.ProcessId } | Where-Object { $_.MainWindowHandle -ne 0 })
if ($owned.Count -ne 1) { throw 'Expected one window in the isolated GMod installation.' }
$game = $owned[0]
$minecraft = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'java.exe' -and $_.CommandLine -like "*-Dgarrycraft.bridge=$RunRoot*" })
if ($minecraft.Count -ne 1) { throw 'Expected one Minecraft process for this run directory.' }

# Source accepts console commands through the same WM_COPYDATA message as its -hijack launcher flag.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GarryCraftVideoTest {
    [StructLayout(LayoutKind.Sequential)]
    private struct CopyData { public IntPtr tag; public int length; public IntPtr data; }
    [DllImport("user32.dll", SetLastError=true)]
    private static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr sender,
        ref CopyData data, uint flags, uint timeout, out IntPtr result);
    public static void Resize(IntPtr window, int width, int height) {
        string command = "mat_setvideomode " + width + " " + height + " 1";
        IntPtr buffer = Marshal.StringToHGlobalAnsi(command);
        try {
            var data = new CopyData { tag=IntPtr.Zero, length=command.Length+1, data=buffer };
            IntPtr result;
            if (SendMessageTimeout(window, 0x4A, IntPtr.Zero, ref data, 2, 5000, out result)==IntPtr.Zero)
                throw new InvalidOperationException("Source did not accept the video mode command.");
        } finally { Marshal.FreeHGlobal(buffer); }
    }
}
'@
$artifacts = Join-Path $RunRoot 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$samples = @()
for ($round = 1; $round -le 3; $round++) {
    foreach ($size in @(@(1920,1080), @(1280,720))) {
        $before = & "$PSScriptRoot\Observe.ps1" -Bridge "$RunRoot\bridge.bin"
        [GarryCraftVideoTest]::Resize($game.MainWindowHandle, $size[0], $size[1])
        Start-Sleep -Seconds 3
        $game.Refresh()
        if ($game.HasExited) { throw 'GMod exited during the resolution test.' }
        $state = & "$PSScriptRoot\Observe.ps1" -Bridge "$RunRoot\bridge.bin"
        if (-not $state.linked) { throw 'The bridge lost Minecraft during the resolution test.' }
        if ($state.frame -le $before.frame -or -not (Get-Process -Id $minecraft[0].ProcessId -ErrorAction SilentlyContinue)) {
            throw 'Minecraft stopped publishing during the resolution test.'
        }
        $shot = "$artifacts\resolution-$round-$($size[0])x$($size[1]).png"
        if ($Screenshots) { & um win shot $shot --exe gmod.exe --scale 0.5 }
        $samples += @{round=$round; width=$size[0]; height=$size[1]; pid=$game.Id; minecraftPid=$minecraft[0].ProcessId;
            frame=$state.frame; linked=$state.linked; renderInstance=$state.renderInstance; screenshot=$shot}
    }
}
$samples | ConvertTo-Json | Set-Content -LiteralPath "$artifacts\resolution-changes.json"
Write-Output "Six video mode changes passed. Artifact: $artifacts\resolution-changes.json"
