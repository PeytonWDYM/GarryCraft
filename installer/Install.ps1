param([string]$GmodPath, [string]$InstallRoot = "$env:LOCALAPPDATA/GarryCraft/player", [switch]$RuntimeOnly, [switch]$NoDownloadCache)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
. "$PSScriptRoot/Downloads.ps1"
. "$PSScriptRoot/Release.ps1"
. "$PSScriptRoot/GameFiles.ps1"
. "$PSScriptRoot/Prepare-Runtime.ps1"
$package = Split-Path -Parent $PSScriptRoot
$mutex = $null
$owns = $false
$transcript = $false
$manualReady = $false
try {
    Write-Host 'GarryCraft V1 - Windows x64 / single-player' -ForegroundColor Cyan
    Write-Host '[1/4] Check package and Garry''s Mod' -ForegroundColor Cyan
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { throw 'GarryCraft requires Windows x64 on an Intel or AMD processor.' }
    if (-not (Test-Path -LiteralPath "$package/release.json")) {
        $properties = "$package/fabric/gradle.properties"
        if (-not (Test-Path -LiteralPath $properties)) { throw 'Extract the entire release ZIP, then open Install.cmd from its folder.' }
        $version = [regex]::Match([IO.File]::ReadAllText($properties), '(?m)^version=(.+)').Groups[1].Value.Trim()
        $release = Get-ReleasePackage $version
        & "$release/installer/Install.ps1" @PSBoundParameters
        $result = $LASTEXITCODE
        if ($result -eq 0 -and -not $RuntimeOnly) {
            Copy-Item -LiteralPath "$release/player.json" -Destination "$package/player.json" -Force
            Write-Host "Open $package\Play.cmd. Select Start New Game > Sandbox > any map > Single Player."
        }
        exit $result
    }
    $manifest = Get-Content -LiteralPath "$package/release.json" -Raw | ConvertFrom-Json
    foreach ($file in $manifest.payload) {
        if ((Get-FileHash -LiteralPath "$package/payload/$($file.path)" -Algorithm SHA256).Hash -ne $file.sha256) {
            throw "Package checksum failed: $($file.path). Download and extract the release ZIP again."
        }
    }
    if (-not $GmodPath) {
        $games = @(Find-Gmod)
        if ($games.Count -eq 1) { $GmodPath = $games[0] }
        else {
            foreach ($game in $games) { Write-Host "Found: $game" }
            Write-Host 'Steam > Garry''s Mod > Properties > Installed Files > Browse'
            $GmodPath = (Read-Host 'Paste the GarrysMod folder path').Trim('"')
        }
    }
    Assert-Game $GmodPath $manifest.engineBuilds
    $GmodPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$GmodPath/bin/win64/gmod.exe")))
    if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Close Garry''s Mod before installation.' }
    Write-Host "Game: $GmodPath"
    $InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
    if ((Test-Path -LiteralPath $InstallRoot) -and -not (Test-Path -LiteralPath "$InstallRoot/.garrycraft-player")) {
        throw "This directory is not a GarryCraft player installation: $InstallRoot. Select a new empty path with -InstallRoot."
    }
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    if (-not (Test-Path -LiteralPath "$InstallRoot/.garrycraft-player")) {
        [IO.File]::WriteAllText("$InstallRoot/.garrycraft-player", 'GarryCraft player installation')
    }
    $InstallRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$InstallRoot/.garrycraft-player")
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($InstallRoot))).Replace('-', '')
    $mutex = New-Object Threading.Mutex($false, "Local\GarryCraftRuntime-$hash")
    try { $owns = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owns = $true }
    if (-not $owns) { throw 'Minecraft is still running or saving. Wait for it to exit, then rerun Install.cmd.' }
    $log = "$InstallRoot/install-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff')).log"
    Start-Transcript -Path $log | Out-Null
    $transcript = $true
    Write-Host "Player installation: $InstallRoot"
    Prepare-Runtime $manifest $InstallRoot $package ([bool]$NoDownloadCache)
    Write-Host '[3/4] Prepare game files' -ForegroundColor Cyan
    $manual = "$InstallRoot/manual"
    foreach ($file in $manifest.payload | Where-Object { $_.path.StartsWith('garrysmod/') }) {
        $target = Join-Path $manual $file.path
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath "$package/payload/$($file.path)" -Destination $target -Force
    }
    New-Item -ItemType Directory -Path "$manual/garrysmod/data" -Force | Out-Null
    [IO.File]::WriteAllText("$manual/garrysmod/data/garrycraft-runtime.json", (@{root=$InstallRoot.Replace('\','/')} | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText("$InstallRoot/install.json", (@{version=$manifest.version; game=$GmodPath} | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    $manualReady = $true
    if ($RuntimeOnly) { Show-ManualCopy $InstallRoot $GmodPath }
    else {
        if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Garry''s Mod started during setup. Close it, then rerun Install.cmd.' }
        $paths = @($manifest.payload | Where-Object { $_.path.StartsWith('garrysmod/') } | ForEach-Object { $_.path }) + @('garrysmod/data/garrycraft-runtime.json')
        $backup = "$InstallRoot/backups/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff'))"
        Install-GameFiles $manual $GmodPath $backup $paths
        [IO.File]::WriteAllText("$package/player.json", (@{root=$InstallRoot} | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
        Write-Host '[4/4] Installation complete' -ForegroundColor Green
        Write-Host "Open $package\Play.cmd. Select Start New Game > Sandbox > any map > Single Player."
        Write-Host 'Use Spawn Menu > Utilities > GarryCraft to enable or disable the bridge.'
    }
    Write-Host "Install log: $log"
    Write-Host "Worlds: $InstallRoot\worlds"
    Write-Host "Minecraft mods: $InstallRoot\minecraft\mods"
    exit 0
} catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($manualReady) { Show-ManualCopy $InstallRoot $GmodPath }
    Write-Host "Read $package\docs\INSTALL.md for recovery steps."
    if ($log) { Write-Host "Install log: $log" }
    exit 1
} finally {
    if ($transcript) { Stop-Transcript | Out-Null }
    if ($owns) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
}
