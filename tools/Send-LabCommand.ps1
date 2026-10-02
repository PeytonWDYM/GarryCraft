param([Parameter(Mandatory)][int]$GamePid, [Parameter(Mandatory)][string]$Command,
    [Parameter(Mandatory)][string]$LabPath)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Console control requires an owned Source lab.' }
$gameProcess = Get-Process -Id $GamePid
$expected = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$LabPath/bin/win64/gmod.exe"
$actual = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File $gameProcess.MainModule.FileName
if ($actual -ne $expected) { throw 'The process does not belong to the requested Source lab.' }
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GarryCraftLabConsole {
    [StructLayout(LayoutKind.Sequential)] struct CopyData { public IntPtr tag; public int length; public IntPtr data; }
    [DllImport("user32.dll", SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr sender, ref CopyData data, uint flags, uint timeout, out IntPtr result);
    public static void Send(IntPtr window, string command) {
        var buffer = Marshal.StringToHGlobalAnsi(command);
        try {
            var data = new CopyData { tag=IntPtr.Zero, length=command.Length+1, data=buffer };
            IntPtr result;
            if (SendMessageTimeout(window, 0x4A, IntPtr.Zero, ref data, 2, 5000, out result) == IntPtr.Zero)
                throw new InvalidOperationException("The Source lab did not accept the console command.");
        } finally { Marshal.FreeHGlobal(buffer); }
    }
}
'@
[GarryCraftLabConsole]::Send($gameProcess.MainWindowHandle, $Command)
