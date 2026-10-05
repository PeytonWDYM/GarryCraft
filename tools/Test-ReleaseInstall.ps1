param([Parameter(Mandatory)][string]$Package, [Parameter(Mandatory)][string]$LabPath,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/release-tests/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$LabPath/.garrycraft-lab")) { throw 'Use a marked, separate game installation.' }
if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Close Garry''s Mod before installer tests. Run game-launch tests after this script completes.' }
if (Test-Path $RunRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
[IO.File]::WriteAllText("$RunRoot/owner", 'release-install-tests')
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/owner")
$checks = [ordered]@{}
$fixture = "$RunRoot/game fixture"
$runtime = Join-Path $RunRoot 'player runtime'
$checks.cleanRuntimeBeforeSetup = -not (Test-Path -LiteralPath $runtime)
Write-Host "CLEAN INSTALL TEST: runtime=$runtime; game=$fixture; external download caches are disabled."
$extract = "$RunRoot/package space caf$([char]0xe9)"
Expand-Archive -LiteralPath $Package -DestinationPath $extract
$shell = "$env:WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
function Install($Name, [string[]]$Extra, [string]$Game = $fixture) {
    & $shell -NoProfile -ExecutionPolicy Bypass -File "$extract/installer/Install.ps1" -GmodPath $Game -InstallRoot $runtime -NoDownloadCache @Extra *> "$RunRoot/$Name.log"
    return $LASTEXITCODE
}
try {
    # This fixture cannot launch a game. It permits real file operations without touching a player's installation.
    New-Item -ItemType Directory -Path "$fixture/bin/win64", "$fixture/garrysmod" -Force | Out-Null
    foreach ($name in 'gmod.exe', 'client.dll', 'engine.dll', 'materialsystem.dll', 'studiorender.dll') {
        Copy-Item "$LabPath/bin/win64/$name" "$fixture/bin/win64/$name"
    }
    $checks.cleanGameBeforeSetup = -not (Test-Path "$fixture/garrysmod/addons/garrycraft") -and
        -not (Test-Path "$fixture/garrysmod/lua/bin") -and -not (Test-Path "$fixture/garrysmod/data/garrycraft-runtime.json")
    $checks.invalidPath = (Install 'invalid-path' @() "$RunRoot/missing") -ne 0
    $checks.noWritesForInvalidPath = -not (Test-Path $runtime)
    $dll = "$extract/payload/garrysmod/lua/bin/gmcl_garrycraft_win64.dll"
    $bytes = [IO.File]::ReadAllBytes($dll)
    [IO.File]::WriteAllText($dll, 'corrupt')
    $checks.corruptPackage = (Install 'corrupt-package' @()) -ne 0
    [IO.File]::WriteAllBytes($dll, $bytes)
    $checks.noWritesForCorruption = -not (Test-Path "$fixture/garrysmod/lua/bin")
    $engine = "$fixture/bin/win64/engine.dll"
    $originalEngine = [IO.File]::ReadAllBytes($engine)
    [IO.File]::WriteAllText($engine, 'wrong engine')
    $checks.wrongEngine = (Install 'wrong-engine' @()) -ne 0
    [IO.File]::WriteAllBytes($engine, $originalEngine)
    $checks.runtimeOnly = (Install 'runtime-only' @('-RuntimeOnly')) -eq 0
    $checks.noGameWriteForRuntimeOnly = -not (Test-Path "$fixture/garrysmod/lua/bin")
    $checks.noFolderLauncherForRuntimeOnly = -not (Test-Path -LiteralPath "$extract/player.json")
    $checks.manualPointer = (Get-Content "$runtime/manual/garrysmod/data/garrycraft-runtime.json" -Raw | ConvertFrom-Json).root -eq $runtime.Replace('\','/')
    $checks.freshInstall = (Install 'fresh-install' @()) -eq 0
    $checks.folderLauncherTargetsPlayer = (Get-Content "$extract/player.json" -Raw | ConvertFrom-Json).root -eq $runtime
    $manifest = Get-Content "$extract/release.json" -Raw | ConvertFrom-Json
    $checks.installedFilesMatch = $true
    foreach ($file in $manifest.payload | Where-Object { $_.path.StartsWith('garrysmod/') }) {
        if ((Get-FileHash "$fixture/$($file.path)" -Algorithm SHA256).Hash -ne $file.sha256) { $checks.installedFilesMatch = $false }
    }
    New-Item -ItemType Directory -Path "$runtime/worlds/sentinel", "$fixture/garrysmod/addons/unrelated" -Force | Out-Null
    [IO.File]::WriteAllText("$runtime/worlds/sentinel/keep.txt", 'world')
    [IO.File]::WriteAllText("$runtime/settings/options.txt", 'preferences')
    [IO.File]::WriteAllText("$fixture/garrysmod/addons/unrelated/keep.txt", 'addon')
    $checks.rerun = (Install 'rerun' @()) -eq 0
    $checks.preserveWorld = [IO.File]::ReadAllText("$runtime/worlds/sentinel/keep.txt") -eq 'world'
    $checks.preservePreferences = [IO.File]::ReadAllText("$runtime/settings/options.txt") -eq 'preferences'
    $checks.preserveUnrelatedAddon = [IO.File]::ReadAllText("$fixture/garrysmod/addons/unrelated/keep.txt") -eq 'addon'
    # Deny replacement of the last module. Earlier copies must roll back.
    $serverDll = "$fixture/garrysmod/lua/bin/gmsv_garrycraft_win64.dll"
    $clientDll = "$fixture/garrysmod/lua/bin/gmcl_garrycraft_win64.dll"
    [IO.File]::WriteAllText($clientDll, 'previous-client')
    $lock = [IO.File]::Open($serverDll, 'Open', 'Read', 'Read')
    try { $checks.lockedFile = (Install 'locked-file' @()) -ne 0 }
    finally { $lock.Dispose() }
    $checks.rollback = [IO.File]::ReadAllText($clientDll) -eq 'previous-client'
    $checks.manualInstructions = (Get-Content "$RunRoot/locked-file.log" -Raw) -match 'Manual copy'
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($runtime))).Replace('-', '')
    $mutex = [Threading.Mutex]::new($false, "Local\GarryCraftRuntime-$hash")
    $owns = $mutex.WaitOne(0)
    try { $checks.busyRuntime = (Install 'busy-runtime' @()) -ne 0 }
    finally { if ($owns) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
    # Exercise a failed download and a checksum mismatch through the actual HTTP client.
    . "$extract/installer/Downloads.ps1"
    $url = 'http://127.0.0.1:1/missing'
    # An unavailable endpoint must leave no verified destination and identify the URL.
    try {
        Get-Downloads @([pscustomobject]@{url=$url; path='bad.bin'; hash=('0' * 40); algorithm='SHA1'}) "$RunRoot/downloads" @()
        $checks.failedDownload = $false
    } catch { $checks.failedDownload = $_.Exception.Message.Contains($url) -and -not (Test-Path "$RunRoot/downloads/bad.bin") }
    $checksumUrl = 'https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.19.5/fabric-loader-0.19.5.jar.sha1'
    try {
        Get-Downloads @([pscustomobject]@{url=$checksumUrl; path='checksum.bin'; hash=('0' * 40); algorithm='SHA1'}) "$RunRoot/downloads" @()
        $checks.wrongChecksum = $false
    } catch { $checks.wrongChecksum = $_.Exception.Message -match 'wrong checksum' -and -not (Test-Path "$RunRoot/downloads/checksum.bin") }
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; package=$Package; directory=$RunRoot; cleanInstall=@{runtime=$runtime; game=$fixture; externalDownloadCaches=$false}} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/release-install-result.json"
    if (-not $passed) { throw 'Release installation failed. Read release-install-result.json.' }
    Get-Content "$RunRoot/release-install-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; directory=$RunRoot} |
        ConvertTo-Json -Depth 6 | Set-Content "$RunRoot/release-install-result.json"
    throw
}
