param([string]$PackageRoot)
$ErrorActionPreference = 'Stop'
try {
    $playerRoot = $PSScriptRoot
    if ($PackageRoot) {
        $PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
        if (-not (Test-Path -LiteralPath "$PackageRoot/player.json")) {
            throw "Run setup first: $PackageRoot\Install.cmd`nAfter setup completes, open Play.cmd in the same folder."
        }
        $playerRoot = (Get-Content -LiteralPath "$PackageRoot/player.json" -Raw | ConvertFrom-Json).root
    }
    if (-not (Test-Path -LiteralPath "$playerRoot/install.json")) {
        $setup = [IO.Path]::GetFullPath("$PSScriptRoot/../Install.cmd")
        if (Test-Path -LiteralPath $setup) {
            throw "Run setup first: $setup`nAfter setup completes, open the Play.cmd path printed by setup."
        }
        throw 'Setup is incomplete for this player folder. Rerun Install.cmd from the extracted release ZIP, then open the Play.cmd path printed by setup.'
    }
    $configuration = Get-Content -LiteralPath "$playerRoot/install.json" -Raw | ConvertFrom-Json
    $game = $configuration.game
    if (-not (Test-Path -LiteralPath "$game/bin/win64/gmod.exe")) { throw "Garry's Mod moved. Rerun Install.cmd with its new folder path." }
    Start-Process -FilePath "$game/bin/win64/gmod.exe" -WorkingDirectory $game -ArgumentList '-insecure -novid -windowed -w 1920 -h 1080 +sv_lan 1 +maxplayers 1'
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
