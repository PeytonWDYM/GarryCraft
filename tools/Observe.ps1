param([string]$Bridge = "$env:LOCALAPPDATA\GarryCraft\bridge.bin")
$ErrorActionPreference = 'Stop'
$stream = [System.IO.FileStream]::new($Bridge, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite, [int]1, [IO.FileOptions]::RandomAccess)
try {
    for ($attempt = 0; $attempt -lt 16; $attempt++) {
    $stream.Position = 65600
    $header = New-Object byte[] 8
    $null = $stream.Read($header, 0, 8)
    $before = [BitConverter]::ToInt32($header, 0)
    if ($before % 2) { continue }
    $length = [BitConverter]::ToInt32($header, 4)
    if ($length -lt 0 -or $length -gt 4MB) { throw 'Invalid snapshot length.' }
    $stream.Position = 65664
    $bytes = New-Object byte[] $length
    $null = $stream.Read($bytes, 0, $length)
    $stream.Position = 65600
    $null = $stream.Read($header, 0, 4)
    if ([BitConverter]::ToInt32($header, 0) -ne $before) { continue }
    return [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
    }
    throw 'Snapshot changed during each read attempt. Run the command again.'
} finally { $stream.Dispose() }
