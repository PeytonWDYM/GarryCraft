param([Parameter(Mandatory)][string]$Package, [Parameter(Mandatory)][string]$LabPath,
    [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Use a marked installer fixture.' }
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new result directory.' }
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$packageRoot = "$RunRoot/package [space] caf$([char]0xe9) & test"
Expand-Archive -LiteralPath $Package -DestinationPath $packageRoot
$checks = [ordered]@{}
$game = "$RunRoot/custom game [one]"
$runtime = "$RunRoot/custom player [one] caf$([char]0xe9)"
function Fixture([string]$Root = $runtime, [string]$GameRoot = $game) {
    New-Item -ItemType Directory -Path "$GameRoot/bin/win64", "$GameRoot/garrysmod/data", "$GameRoot/garrysmod/addons/unrelated", "$Root/worlds/sentinel", "$Root/settings", "$Root/java", "$Root/minecraft/mods" -Force | Out-Null
    Copy-Item -LiteralPath "$LabPath/bin/win64/gmod.exe" -Destination "$GameRoot/bin/win64/gmod.exe" -Force
    Copy-Item -LiteralPath "$packageRoot/payload/garrysmod/addons/garrycraft" -Destination "$GameRoot/garrysmod/addons" -Recurse -Force
    New-Item -ItemType Directory -Path "$GameRoot/garrysmod/cfg" -Force | Out-Null
    Copy-Item -LiteralPath "$packageRoot/payload/garrysmod/cfg/garrycraft-session.cfg" -Destination "$GameRoot/garrysmod/cfg" -Force
    New-Item -ItemType Directory -Path "$GameRoot/garrysmod/lua/bin" -Force | Out-Null
    foreach ($realm in 'gmcl','gmsv') { Copy-Item -LiteralPath "$packageRoot/payload/garrysmod/lua/bin/${realm}_garrycraft_win64.dll" -Destination "$GameRoot/garrysmod/lua/bin" -Force }
    [IO.File]::WriteAllText("$Root/.garrycraft-player", 'GarryCraft player installation')
    @{version='1.0.4';game=[IO.Path]::GetFullPath($GameRoot)} | ConvertTo-Json | Set-Content -LiteralPath "$Root/install.json" -Encoding UTF8
    @{root=[IO.Path]::GetFullPath($Root)} | ConvertTo-Json | Set-Content -LiteralPath "$packageRoot/player.json" -Encoding UTF8
    @{root=[IO.Path]::GetFullPath($Root)} | ConvertTo-Json | Set-Content -LiteralPath "$GameRoot/garrysmod/data/garrycraft-runtime.json" -Encoding UTF8
    [IO.File]::WriteAllText("$Root/worlds/sentinel/keep.txt", 'world')
    [IO.File]::WriteAllText("$Root/settings/options.txt", 'preferences')
    [IO.File]::WriteAllText("$Root/java/installed.txt", 'runtime')
    [IO.File]::WriteAllText("$GameRoot/garrysmod/addons/unrelated/keep.txt", 'addon')
    Copy-Item -LiteralPath "$packageRoot/installer/Uninstall.cmd.template" -Destination "$Root/Uninstall.cmd" -Force
    foreach ($name in 'Uninstall.ps1','UninstallPaths.ps1','GameFiles.ps1','Resolve-LocalPath.ps1') { Copy-Item -LiteralPath "$packageRoot/installer/$name" -Destination $Root -Force }
}
function Uninstall([string]$Name, [string]$Extra = '', [string]$Entry = "$packageRoot/Uninstall.cmd") {
    $command = 'call "' + $Entry + '" ' + $Extra + ' < nul'
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/$Name.log"
    return $LASTEXITCODE
}
try {
    Fixture
    $checks.defaultUninstall = (Uninstall 'default') -eq 0
    $checks.gamePayloadRemoved = -not (Test-Path -LiteralPath "$game/garrysmod/addons/garrycraft") -and -not (Test-Path -LiteralPath "$game/garrysmod/lua/bin/gmcl_garrycraft_win64.dll") -and -not (Test-Path -LiteralPath "$game/garrysmod/data/garrycraft-runtime.json")
    $checks.dependenciesRemoved = -not (Test-Path -LiteralPath "$runtime/java") -and -not (Test-Path -LiteralPath "$runtime/minecraft")
    $checks.launchConfigRemoved = -not (Test-Path -LiteralPath "$game/garrysmod/cfg/garrycraft-session.cfg")
    $checks.worldPreserved = [IO.File]::ReadAllText("$runtime/worlds/sentinel/keep.txt") -eq 'world'
    $checks.preferencesPreserved = [IO.File]::ReadAllText("$runtime/settings/options.txt") -eq 'preferences'
    $checks.unrelatedAddonPreserved = [IO.File]::ReadAllText("$game/garrysmod/addons/unrelated/keep.txt") -eq 'addon'
    $checks.gamePreserved = Test-Path -LiteralPath "$game/bin/win64/gmod.exe"
    $checks.repeatUninstall = (Uninstall 'repeat' ('-InstallRoot "' + $runtime + '"')) -eq 0
    Fixture
    $checks.installedEntry = (Uninstall 'installed-entry' '' "$runtime/Uninstall.cmd") -eq 0
    Fixture
    $checks.installedPurge = (Uninstall 'installed-purge' '-Purge' "$runtime/Uninstall.cmd") -eq 0 -and -not (Test-Path -LiteralPath $runtime)
    Fixture
    $lockedModule = [IO.File]::Open("$game/garrysmod/lua/bin/gmsv_garrycraft_win64.dll", 'Open', 'Read', 'Read')
    try { $checks.lockedModuleRejected = (Uninstall 'locked-module' '-Purge') -ne 0 }
    finally { $lockedModule.Dispose() }
    $checks.lockedModuleRetainsPayload = (Test-Path -LiteralPath "$game/garrysmod/addons/garrycraft/lua/autorun/garrycraft.lua") -and (Test-Path -LiteralPath "$runtime/worlds/sentinel/keep.txt")
    $canonicalRoot = [IO.Path]::GetFullPath($runtime)
    $mutexHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($canonicalRoot))).Replace('-', '')
    $mutex = [Threading.Mutex]::new($false, "Local\GarryCraftRuntime-$mutexHash")
    $owns = $mutex.WaitOne(0)
    try { $checks.busyRuntimeRejected = (Uninstall 'busy-runtime' '-Purge') -ne 0 }
    finally { if ($owns) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
    $unmarked = "$RunRoot/unmarked"
    New-Item -ItemType Directory -Path $unmarked | Out-Null
    [IO.File]::WriteAllText("$unmarked/keep.txt", 'unrelated')
    $checks.unmarkedRejected = (Uninstall 'unmarked' ('-InstallRoot "' + $unmarked + '" -Purge')) -ne 0 -and (Test-Path -LiteralPath "$unmarked/keep.txt")
    $checks.gameRootRejected = (Uninstall 'game-root' ('-InstallRoot "' + $game + '" -Purge')) -ne 0
    $checks.packageRootRejected = (Uninstall 'package-root' ('-InstallRoot "' + $packageRoot + '" -Purge')) -ne 0
    $checks.driveRootRejected = (Uninstall 'drive-root' ('-InstallRoot "' + [IO.Path]::GetPathRoot($RunRoot) + '" -Purge')) -ne 0
    $other = "$RunRoot/other player"
    Fixture $other $game
    $checks.otherRuntimeUninstall = (Uninstall 'other-runtime' ('-InstallRoot "' + $runtime + '" -Purge')) -eq 0
    $checks.activeOwnerPreserved = (Test-Path -LiteralPath "$game/garrysmod/addons/garrycraft/lua/autorun/garrycraft.lua") -and (Get-Content -LiteralPath "$game/garrysmod/data/garrycraft-runtime.json" -Raw | ConvertFrom-Json).root -eq [IO.Path]::GetFullPath($other)
    $checks.purge = (Uninstall 'purge' ('-InstallRoot "' + $other + '" -Purge')) -eq 0 -and -not (Test-Path -LiteralPath $other)
    $checks.purgeRepeat = (Uninstall 'purge-repeat' ('-InstallRoot "' + $other + '" -Purge')) -eq 0
    Fixture
    $outside = "$RunRoot/outside"
    New-Item -ItemType Directory -Path $outside | Out-Null
    [IO.File]::WriteAllText("$outside/keep.txt", 'outside')
    New-Item -ItemType Junction -Path "$runtime/java/redirect" -Target $outside | Out-Null
    $checks.redirectRejected = (Uninstall 'redirect' '-Purge') -ne 0 -and (Test-Path -LiteralPath "$outside/keep.txt")
    # Remove only the junction, then exercise the complete purge.
    [IO.Directory]::Delete("$runtime/java/redirect")
    $checks.purgeAfterRedirect = (Uninstall 'purge-after-redirect' '-Purge') -eq 0 -and -not (Test-Path -LiteralPath $runtime)
    Fixture
    # This directory was created and marked by Fixture. The package and game pointer remain.
    Remove-Item -LiteralPath $runtime -Recurse -Force
    $checks.missingRuntime = (Uninstall 'missing-runtime' ('-GmodPath "' + $game + '" -Purge')) -eq 0 -and -not (Test-Path -LiteralPath "$game/garrysmod/addons/garrycraft")
    Fixture
    $movedGame = "$RunRoot/relocated game"
    Move-Item -LiteralPath $game -Destination $movedGame
    $checks.relocatedGame = (Uninstall 'relocated-game' ('-GmodPath "' + $movedGame + '" -Purge')) -eq 0 -and -not (Test-Path -LiteralPath "$movedGame/garrysmod/addons/garrycraft")
    $game = $movedGame
    Fixture
    $movedPackage = "$RunRoot/moved package"
    Move-Item -LiteralPath $packageRoot -Destination $movedPackage
    $packageRoot = $movedPackage
    $checks.movedPackage = (Uninstall 'moved-package' '-Purge' "$packageRoot/Uninstall.cmd") -eq 0 -and -not (Test-Path -LiteralPath $runtime)
    $checks.packagePreserved = (Test-Path -LiteralPath "$packageRoot/Install.cmd") -and (Test-Path -LiteralPath "$packageRoot/Uninstall.cmd")
    Fixture
    $privateAddons = "$game/garrysmod/private-addons"
    Move-Item -LiteralPath "$game/garrysmod/addons" -Destination $privateAddons
    New-Item -ItemType Directory -Path "$outside/garrycraft" -Force | Out-Null
    New-Item -ItemType Junction -Path "$game/garrysmod/addons" -Target $outside | Out-Null
    $checks.gameParentRedirectRejected = (Uninstall 'game-parent-redirect' '-Purge') -ne 0 -and (Test-Path -LiteralPath "$runtime/worlds/sentinel/keep.txt") -and (Test-Path -LiteralPath "$outside/keep.txt")
    [IO.Directory]::Delete("$game/garrysmod/addons")
    Move-Item -LiteralPath $privateAddons -Destination "$game/garrysmod/addons"
    # Move the owned fixture aside to simulate a game removed from its recorded path.
    Move-Item -LiteralPath $game -Destination "$RunRoot/removed-game-fixture"
    $checks.removedGame = (Uninstall 'removed-game' '-Purge') -eq 0 -and -not (Test-Path -LiteralPath $runtime)
    $result = @{passed=-not ($checks.Values -contains $false); checks=$checks; directory=$RunRoot}
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$RunRoot/uninstall-result.json"
    if (-not $result.passed) { throw 'Uninstall checks failed.' }
    $result | ConvertTo-Json -Depth 5
} catch {
    @{passed=$false;checks=$checks;error=$_.Exception.Message} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$RunRoot/uninstall-result.json"
    throw
}
