Add-Type -AssemblyName System.Net.Http

# Verify cached files and replace incomplete downloads. Keep at most twelve requests active.
function Get-Downloads($Files, [string]$Root, [string[]]$CacheRoots) {
    $client = New-Object Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromMinutes(5)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('GarryCraft/1.0')
    $pending = New-Object 'Collections.Generic.List[object]'
    $completed = 0
    try {
        foreach ($file in $Files) {
            $target = Join-Path $Root $file.path
            if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm $file.algorithm).Hash -eq $file.hash) {
                $completed++
                if ($completed % 500 -eq 0) { Write-Host "  Verified $completed / $($Files.Count) files" }
                continue
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            $cached = $false
            foreach ($cache in $CacheRoots) {
                $source = Join-Path $cache $file.path
                if ((Test-Path -LiteralPath $source -PathType Leaf) -and (Get-FileHash -LiteralPath $source -Algorithm $file.algorithm).Hash -eq $file.hash) {
                    Copy-Item -LiteralPath $source -Destination $target -Force
                    $cached = $true
                    break
                }
            }
            if ($cached) {
                $completed++
                if ($completed % 500 -eq 0) { Write-Host "  Verified $completed / $($Files.Count) files" }
                continue
            }
            $pending.Add(@{file=$file; target=$target; task=$client.GetByteArrayAsync([string]$file.url)})
            if ($pending.Count -ge 12) {
                Complete-Download $pending[0]
                $pending.RemoveAt(0)
                $completed++
                if ($completed % 100 -eq 0) { Write-Host "  Downloaded $completed / $($Files.Count) files" }
            }
        }
        foreach ($entry in $pending) { Complete-Download $entry; $completed++ }
        Write-Host "  Verified $completed files"
    } finally { $client.Dispose() }
}

function Complete-Download($Entry) {
    $temporary = "$($Entry.target).download"
    try {
        $bytes = $Entry.task.GetAwaiter().GetResult()
        [IO.File]::WriteAllBytes($temporary, $bytes)
        if ((Get-FileHash -LiteralPath $temporary -Algorithm $Entry.file.algorithm).Hash -ne $Entry.file.hash) {
            throw 'The downloaded file has the wrong checksum.'
        }
        Move-Item -LiteralPath $temporary -Destination $Entry.target -Force
    } catch {
        throw "Download failed: $($Entry.file.url)`nDestination: $($Entry.target)`n$($_.Exception.Message)`nCheck your connection and rerun Install.cmd. Verified downloads will be reused."
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}
