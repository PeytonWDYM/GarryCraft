param([string]$PackageRoot)
$ErrorActionPreference = 'Stop'
try {
    $playerRoot = $PSScriptRoot
    if ($PackageRoot) {
        $PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
        if (-not (Test-Path -LiteralPath "$PackageRoot/player.json")) {
            throw "Run setup first: $PackageRoot\Install.cmd`nAfter setup completes, open Play.cmd in the same folder."
        }
        $playerRoot = (Get-Content -LiteralPath "$PackageRoot/player.json" -Raw -Encoding UTF8 | ConvertFrom-Json).root
    }
    if (-not (Test-Path -LiteralPath "$playerRoot/install.json")) {
        $setup = [IO.Path]::GetFullPath("$PSScriptRoot/../Install.cmd")
        if (Test-Path -LiteralPath $setup) {
            throw "Run setup first: $setup`nAfter setup completes, open the Play.cmd path printed by setup."
        }
        throw 'Setup is incomplete for this player folder. Rerun Install.cmd from the extracted release ZIP, then open the Play.cmd path printed by setup.'
    }
    $configuration = Get-Content -LiteralPath "$playerRoot/install.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $game = $configuration.game
    if (-not (Test-Path -LiteralPath "$game/bin/win64/gmod.exe")) { throw "Garry's Mod moved. Rerun Install.cmd with its new folder path." }
    if ($game -match '[^\x00-\x7F]') { throw 'GMod needs an ASCII game folder path. Move the game through Steam''s Storage settings, then rerun Install.cmd.' }
    if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Close Garry''s Mod, then open Play.cmd to start a GarryCraft session.' }
    $start = New-Object Diagnostics.ProcessStartInfo("$game/bin/win64/gmod.exe", '-insecure -novid -windowed -w 1920 -h 1080 +sv_lan 1 +maxplayers 1 +exec garrycraft-session.cfg')
    $start.WorkingDirectory = $game
    $start.UseShellExecute = $false
    [Diagnostics.Process]::Start($start) | Out-Null
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
