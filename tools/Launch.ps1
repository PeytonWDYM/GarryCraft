$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$settings = Join-Path $repository '.garrycraft-local.json'
try {
    if (-not (Test-Path -LiteralPath $settings)) { throw 'Run tools/Setup-Lab.ps1 once to prepare GarryCraft.' }
    $configuration = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    $running = Get-CimInstance Win32_Process -Filter "name='gmod.exe'" |
        Where-Object { $_.ExecutablePath -eq $configuration.game -and $_.CommandLine -notmatch '--type=' }
    if ($running) {
        (New-Object -ComObject WScript.Shell).AppActivate([int]@($running)[0].ProcessId) | Out-Null
        exit
    }
    Start-Process -FilePath $configuration.shortcut
} catch { Write-Error $_.Exception.Message; exit 1 }
