$ErrorActionPreference = 'Stop'
try {
    $configuration = Get-Content -LiteralPath "$PSScriptRoot/install.json" -Raw | ConvertFrom-Json
    $game = $configuration.game
    if (-not (Test-Path -LiteralPath "$game/bin/win64/gmod.exe")) { throw "Garry's Mod moved. Rerun Install.cmd with its new folder path." }
    Start-Process -FilePath "$game/bin/win64/gmod.exe" -WorkingDirectory $game -ArgumentList '-insecure -novid +sv_lan 1 +maxplayers 1'
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
