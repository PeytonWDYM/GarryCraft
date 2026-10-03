param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'
# Runtime status uses atomic replacement. Permit replacement while reading the complete opened generation.
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $stream = [IO.FileStream]::new($Path, 'Open', 'Read', [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
        $reader = [IO.StreamReader]::new($stream)
        try { return $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
    } catch [IO.IOException] {
        if (($_.Exception.HResult -band 0xffff) -notin 32, 33 -or $attempt -eq 29) { throw }
        Start-Sleep -Milliseconds 10
    }
}
