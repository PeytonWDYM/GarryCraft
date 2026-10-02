# Source can hold JSON files open without delete sharing. Keep the last complete snapshot until replacement succeeds.
function Write-JsonFile($Path, $Value) {
    $temporary = "$Path.tmp"
    [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Compress -Depth 8), (New-Object Text.UTF8Encoding($false)))
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, "$Path.previous") }
            else { [IO.File]::Move($temporary, $Path) }
            return $true
        } catch [IO.IOException] {
            if (($_.Exception.HResult -band 0xffff) -notin 32, 33) { throw }
            if ($attempt -lt 4) { Start-Sleep -Milliseconds 10 }
        }
    }
    return $false
}
