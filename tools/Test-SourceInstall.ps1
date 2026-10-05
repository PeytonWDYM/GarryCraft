param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/source-install-tests/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$LabPath/.garrycraft-lab")) { throw 'Use a marked, separate game installation.' }
if (-not (Test-Path "$RuntimeRoot/.garrycraft-player")) { throw 'Use an owned test player runtime.' }
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/.garrycraft-player")
if (Test-Path $RunRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
[IO.File]::WriteAllText("$RunRoot/owner", 'source-install-tests')
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/owner")
$checkout = "$RunRoot/source checkout"
$fixture = "$RunRoot/game fixture"
New-Item -ItemType Directory -Path "$checkout/fabric", "$checkout/docs", "$fixture/bin/win64", "$fixture/garrysmod/addons/unrelated" -Force | Out-Null
Copy-Item "$repository/Install.cmd" $checkout
Copy-Item "$repository/installer" $checkout -Recurse
Copy-Item "$repository/fabric/gradle.properties" "$checkout/fabric/"
Copy-Item "$repository/docs/INSTALL.md" "$checkout/docs/"
foreach ($name in 'gmod.exe','client.dll','engine.dll','studiorender.dll','materialsystem.dll') {
    Copy-Item "$LabPath/bin/win64/$name" "$fixture/bin/win64/"
}
[IO.File]::WriteAllText("$fixture/garrysmod/addons/unrelated/keep.txt", 'addon')
$checks = [ordered]@{}
try {
    # NUL lets CMD's final pause complete without an interactive terminal.
    $command = 'call "' + "$checkout/Install.cmd" + '" -GmodPath "' + $fixture + '" -InstallRoot "' + $RuntimeRoot + '" < nul'
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/source-install.log"
    $checks.sourceCmdSucceeds = $LASTEXITCODE -eq 0
    $checks.sourceRemainsWithoutManifest = -not (Test-Path "$checkout/release.json")
    $checks.noBuildToolsRequired = -not (Test-Path "$checkout/native")
    $checks.forwardedRuntime = (Get-Content "$fixture/garrysmod/data/garrycraft-runtime.json" -Raw | ConvertFrom-Json).root -eq $RuntimeRoot.Replace('\','/')
    $checks.modsInstalled = (Test-Path "$RuntimeRoot/minecraft/mods/garrycraft.jar") -and (Test-Path "$RuntimeRoot/minecraft/mods/fabric-api.jar")
    $checks.addonPreserved = [IO.File]::ReadAllText("$fixture/garrysmod/addons/unrelated/keep.txt") -eq 'addon'
    # The same entry point must explain an incomplete ZIP instead of reporting a missing JSON file.
    Remove-Item -LiteralPath "$checkout/fabric/gradle.properties"
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/incomplete-package.log"
    $checks.incompletePackageFails = $LASTEXITCODE -ne 0
    $checks.incompletePackageExplained = (Get-Content "$RunRoot/incomplete-package.log" -Raw) -match 'Extract the entire'
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; directory=$RunRoot} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/source-install-result.json"
    if (-not $passed) { throw 'Source installation checks failed.' }
    Get-Content "$RunRoot/source-install-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/source-install-result.json"
    throw
}
