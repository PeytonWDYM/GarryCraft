# Source checkouts use the published binaries. Build tools remain optional for player setup.
function Get-ReleasePackage([string]$Version) {
    $name = "GarryCraft-$Version-windows-x64.zip"
    $url = "https://github.com/PeytonWDYM/GarryCraft/releases/download/v$Version/$name"
    $localRelease = "$(Split-Path -Parent $PSScriptRoot)/release"
    Write-Host "Source checkout detected. Preparing the compiled installer for $Version." -ForegroundColor Cyan
    try {
        if (Test-Path -LiteralPath "$localRelease/$name.sha256") { $checksum = Get-Content -LiteralPath "$localRelease/$name.sha256" -Raw }
        else { $checksum = [string](Invoke-RestMethod "$url.sha256") }
    }
    catch { throw "Cannot download release $Version. Check your connection or download the release ZIP from GitHub.`nURL: $url.sha256`n$($_.Exception.Message)" }
    $match = [regex]::Match($checksum, '^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($name) + '\s*$')
    if (-not $match.Success) { throw "Invalid release checksum: $url.sha256. Download the release ZIP again." }
    $hash = $match.Groups[1].Value
    $cache = "$env:LOCALAPPDATA/GarryCraft/installers/$Version"
    Get-Downloads @([pscustomobject]@{url=$url; path=$name; hash=$hash; algorithm='SHA256'}) $cache @($localRelease)
    $destination = Join-Path $cache $hash
    Expand-Archive -LiteralPath "$cache/$name" -DestinationPath $destination -Force
    return $destination
}
