$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$settings = Join-Path $repository '.garrycraft-local.json'
try {
    if (-not (Test-Path -LiteralPath $settings)) { throw 'Run tools/Setup-Lab.ps1 once to prepare GarryCraft.' }
    $configuration = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    $expected = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File $configuration.game
    $running = Get-Process gmod -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne 0 -and
            (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File $_.MainModule.FileName) -eq $expected
    }
    if ($running) {
        (New-Object -ComObject WScript.Shell).AppActivate([int]@($running)[0].Id) | Out-Null
        exit
    }
    Start-Process -FilePath $configuration.shortcut
} catch { Write-Error $_.Exception.Message; exit 1 }
