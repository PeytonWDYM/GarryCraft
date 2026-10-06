param([string]$PackageRoot, [string]$InstallRoot, [string]$GmodPath, [switch]$Purge, [switch]$PauseOnExit)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/GameFiles.ps1"
. "$PSScriptRoot/UninstallPaths.ps1"
$resolver = if ($PackageRoot -and -not (Test-Path -LiteralPath "$PackageRoot/release.json")) {
    "$PackageRoot/tools/Resolve-LocalPath.ps1"
} else { "$PSScriptRoot/Resolve-LocalPath.ps1" }
$mutex = $null
$owns = $false
try {
    if ($PackageRoot) { $PackageRoot = [IO.Path]::GetFullPath($PackageRoot) }
    $installation = Find-PlayerInstallation $PackageRoot $InstallRoot $GmodPath
    $root = $installation.root
    $game = $installation.game
    if ($game -and (Get-RunningGmod $game $resolver)) { throw 'Close the selected Garry''s Mod installation before uninstalling GarryCraft.' }
    $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($root))).Replace('-', '')
    $mutex = New-Object Threading.Mutex($false, "Local\GarryCraftRuntime-$hash")
    try { $owns = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owns = $true }
    if (-not $owns) { throw 'Minecraft is still running or saving. Wait for it to exit, then rerun Uninstall.cmd.' }
    $gameTargets = @(Get-UninstallGameTargets $game $root)
    $runtimeTargets = @()
    if (Test-Path -LiteralPath $root) {
        if ($Purge) { $runtimeTargets = @($root) }
        else {
            $programs = @('assets','backups','java','libraries','manual','minecraft','versions','java.zip','java.args','config.json','Play.cmd','Play.ps1','Runtime.ps1','RuntimeFiles.ps1','RuntimeProcess.ps1')
            $runtimeTargets = @($programs | ForEach-Object { "$root/$_" } | Where-Object { Test-Path -LiteralPath $_ })
        }
    }
    $targets = @($gameTargets) + @($runtimeTargets)
    Assert-Unlocked $targets
    Write-Host "Player installation: $root"
    if ($game) { Write-Host "Game: $game" }
    foreach ($target in $targets) { Remove-Item -LiteralPath $target -Recurse -Force }
    if ($PackageRoot -and (Test-Path -LiteralPath "$PackageRoot/player.json")) {
        $pointer = (Get-Content -LiteralPath "$PackageRoot/player.json" -Raw -Encoding UTF8 | ConvertFrom-Json).root
        if ([IO.Path]::GetFullPath($pointer) -eq $root) { Remove-Item -LiteralPath "$PackageRoot/player.json" }
    }
    Write-Host 'GarryCraft uninstalled. Launch Garry''s Mod through Steam for normal play.' -ForegroundColor Green
    if ($Purge) { Write-Host 'The selected player installation, worlds, and settings were removed.' }
    elseif (Test-Path -LiteralPath $root) { Write-Host "Worlds and settings remain in: $root`nReinstall into this player folder to use them again. Use -Purge for a complete reset." }
    exit 0
} catch {
    Write-Host "Uninstall failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($owns) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
    if ($PauseOnExit) { Read-Host 'Press Enter to close' | Out-Null }
}
