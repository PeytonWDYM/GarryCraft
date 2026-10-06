param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RuntimeRoot,
    [string]$Package,
    [string]$RunRoot = "$env:LOCALAPPDATA/GarryCraft/source-install-tests/$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Use a marked, separate game installation.' }
if (-not (Test-Path -LiteralPath "$RuntimeRoot/.garrycraft-player")) { throw 'Use an owned test player runtime.' }
$RuntimeRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RuntimeRoot/.garrycraft-player")
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $RunRoot | Out-Null
[IO.File]::WriteAllText("$RunRoot/owner", 'source-install-tests')
$RunRoot = Split-Path -Parent (& "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$RunRoot/owner")
$checkout = "$RunRoot/source checkout"
$fixture = "$RunRoot/game fixture"
New-Item -ItemType Directory -Path "$checkout/fabric", "$checkout/docs", "$checkout/tools", "$fixture/bin/win64", "$fixture/garrysmod/addons/unrelated" -Force | Out-Null
Copy-Item -LiteralPath "$repository/tools/Resolve-LocalPath.ps1" -Destination "$checkout/tools"
Copy-Item -LiteralPath "$repository/Install.cmd" $checkout
Copy-Item -LiteralPath "$repository/Play.cmd" $checkout
Copy-Item -LiteralPath "$repository/Uninstall.cmd" $checkout
Copy-Item -LiteralPath "$repository/installer" $checkout -Recurse
Copy-Item -LiteralPath "$repository/fabric/gradle.properties" "$checkout/fabric/"
Copy-Item -LiteralPath "$repository/docs/INSTALL.md" "$checkout/docs/"
if ($Package) {
    New-Item -ItemType Directory -Path "$checkout/release" | Out-Null
    $packageName = [IO.Path]::GetFileName($Package)
    Copy-Item -LiteralPath $Package -Destination "$checkout/release/$packageName"
    "$((Get-FileHash -LiteralPath $Package -Algorithm SHA256).Hash)  $packageName" | Set-Content "$checkout/release/$packageName.sha256" -Encoding ascii
}
foreach ($name in 'gmod.exe','client.dll','engine.dll','studiorender.dll','materialsystem.dll') {
    Copy-Item -LiteralPath "$LabPath/bin/win64/$name" "$fixture/bin/win64/"
}
[IO.File]::WriteAllText("$fixture/garrysmod/addons/unrelated/keep.txt", 'addon')
$checks = [ordered]@{}
$preserved = @(foreach ($folder in 'worlds','settings') {
    Get-ChildItem -LiteralPath "$RuntimeRoot/$folder" -File -Recurse | ForEach-Object {
        [pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    }
})
$preserved | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$RunRoot/preserved-before.json"
try {
    # NUL lets CMD's final pause complete without an interactive terminal.
    $command = 'call "' + "$checkout/Install.cmd" + '" -GmodPath "' + $fixture + '" -InstallRoot "' + $RuntimeRoot + '" < nul'
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/source-install.log"
    $checks.sourceCmdSucceeds = $LASTEXITCODE -eq 0
    $checks.sourceRemainsWithoutManifest = -not (Test-Path -LiteralPath "$checkout/release.json")
    $checks.noBuildToolsRequired = -not (Test-Path -LiteralPath "$checkout/native")
    $checks.forwardedRuntime = (Get-Content -LiteralPath "$fixture/garrysmod/data/garrycraft-runtime.json" -Raw -Encoding UTF8 | ConvertFrom-Json).root -eq $RuntimeRoot.Replace('\','/')
    $checks.sourceFolderLauncherTargetsPlayer = (Get-Content -LiteralPath "$checkout/player.json" -Raw -Encoding UTF8 | ConvertFrom-Json).root -eq $RuntimeRoot
    $playMessages = @((Get-Content -LiteralPath "$RunRoot/source-install.log") | Where-Object { $_ -like 'Open *Play.cmd.*' })
    $sourcePlay = [IO.Path]::GetFullPath("$checkout/Play.cmd")
    $checks.printedSourceFolderLauncher = $playMessages.Count -gt 0 -and $playMessages[-1].StartsWith("Open $sourcePlay.")
    $checks.modsInstalled = (Test-Path -LiteralPath "$RuntimeRoot/minecraft/mods/garrycraft.jar") -and (Test-Path -LiteralPath "$RuntimeRoot/minecraft/mods/fabric-api.jar")
    $checks.addonPreserved = [IO.File]::ReadAllText("$fixture/garrysmod/addons/unrelated/keep.txt") -eq 'addon'
    $checks.worldsAndSettingsPreserved = $true
    foreach ($file in $preserved) {
        if (-not (Test-Path -LiteralPath $file.path) -or (Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash -ne $file.sha256) {
            $checks.worldsAndSettingsPreserved = $false
        }
    }
    # The same entry point must explain an incomplete ZIP instead of reporting a missing JSON file.
    Remove-Item -LiteralPath "$checkout/fabric/gradle.properties"
    & "$env:WINDIR/System32/cmd.exe" /d /c $command *> "$RunRoot/incomplete-package.log"
    $checks.incompletePackageFails = $LASTEXITCODE -ne 0
    $checks.incompletePackageExplained = (Get-Content -LiteralPath "$RunRoot/incomplete-package.log" -Raw) -match 'Extract the entire'
    $uninstallCommand = 'call "' + "$checkout/Uninstall.cmd" + '" -Purge < nul'
    & "$env:WINDIR/System32/cmd.exe" /d /c $uninstallCommand *> "$RunRoot/source-uninstall.log"
    $checks.sourceUninstall = $LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $RuntimeRoot)
    $checks.sourceUninstallPreservesCheckout = (Test-Path -LiteralPath "$checkout/Install.cmd") -and (Test-Path -LiteralPath "$fixture/garrysmod/addons/unrelated/keep.txt")
    $passed = -not ($checks.Values -contains $false)
    @{passed=$passed; checks=$checks; directory=$RunRoot} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/source-install-result.json"
    if (-not $passed) { throw 'Source installation checks failed.' }
    Get-Content -LiteralPath "$RunRoot/source-install-result.json"
} catch {
    @{passed=$false; checks=$checks; error=$_.Exception.Message} | ConvertTo-Json -Depth 5 | Set-Content "$RunRoot/source-install-result.json"
    throw
}
