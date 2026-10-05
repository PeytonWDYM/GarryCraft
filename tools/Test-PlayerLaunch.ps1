param([Parameter(Mandatory)][string]$Package,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/player-launch-tests/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$extract = "$RunRoot/package space caf$([char]0xe9)"
$runtime = "$RunRoot/player runtime"
Expand-Archive -LiteralPath $Package -DestinationPath $extract
New-Item -ItemType Directory -Path $runtime | Out-Null
Copy-Item -LiteralPath "$extract/installer/Play.cmd.template" -Destination "$runtime/Play.cmd"
Copy-Item -LiteralPath "$extract/installer/Play.ps1" -Destination $runtime
$checks = [ordered]@{}
function Launch([string]$Name, [string]$Root) {
    # Test the actual CMD entry point. NUL completes its error pause.
    $command = 'call "' + "$Root/Play.cmd" + '" < nul'
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/$Name.log"
    return $LASTEXITCODE
}
try {
    $checks.setupAndPlayInPackageFolder = @(Get-ChildItem -LiteralPath $extract -Filter '*.cmd' -Recurse).Count -eq 2 -and (Test-Path -LiteralPath "$extract/Install.cmd") -and (Test-Path -LiteralPath "$extract/Play.cmd")
    $checks.packageLauncherFails = (Launch 'package-launch' $extract) -ne 0
    $packageLog = Get-Content -LiteralPath "$RunRoot/package-launch.log" -Raw
    $checks.packageSetupPath = $packageLog.Contains([IO.Path]::GetFullPath("$extract/Install.cmd"))
    $checks.packageExplainsPlayerLauncher = $packageLog.Contains('open Play.cmd in the same folder')
    $checks.noMissingFileError = $packageLog -notmatch 'Cannot find path|does not exist'
    $checks.incompleteRuntimeFails = (Launch 'incomplete-runtime' $runtime) -ne 0
    $runtimeLog = Get-Content -LiteralPath "$RunRoot/incomplete-runtime.log" -Raw
    $checks.incompleteRuntimeExplained = $runtimeLog.Contains('Setup is incomplete') -and $runtimeLog.Contains('Rerun Install.cmd')
    # An absent game tests configuration loading without starting either game.
    @{game="$RunRoot/moved game"} | ConvertTo-Json | Set-Content -LiteralPath "$runtime/install.json" -Encoding UTF8
    $checks.movedGameFails = (Launch 'moved-game' $runtime) -ne 0
    $checks.movedGameExplained = (Get-Content -LiteralPath "$RunRoot/moved-game.log" -Raw).Contains('Rerun Install.cmd with its new folder path')
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; package=$Package; directory=$RunRoot} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$RunRoot/player-launch-result.json"
    if (-not $passed) { throw 'Player launcher checks failed. Read player-launch-result.json.' }
    Get-Content -LiteralPath "$RunRoot/player-launch-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message; directory=$RunRoot} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$RunRoot/player-launch-result.json"
    throw
}
