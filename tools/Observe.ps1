param([string]$Bridge = "$env:LOCALAPPDATA\GarryCraft\bridge.bin")
$ErrorActionPreference = 'Stop'
$stream = [System.IO.File]::Open($Bridge, 'Open', 'Read', 'ReadWrite')
try {
    $stream.Position = 65600
    $header = New-Object byte[] 8
    $null = $stream.Read($header, 0, 8)
    $before = [BitConverter]::ToInt32($header, 0)
    if ($before % 2) { throw 'Snapshot is being written. Run the command again.' }
    $length = [BitConverter]::ToInt32($header, 4)
    if ($length -lt 0 -or $length -gt 4MB) { throw 'Invalid snapshot length.' }
    $stream.Position = 65664
    $bytes = New-Object byte[] $length
    $null = $stream.Read($bytes, 0, $length)
    $stream.Position = 65600
    $null = $stream.Read($header, 0, 4)
    if ([BitConverter]::ToInt32($header, 0) -ne $before) { throw 'Snapshot changed. Run the command again.' }
    [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
} finally { $stream.Dispose() }
