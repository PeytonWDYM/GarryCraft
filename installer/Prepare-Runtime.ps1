function Prepare-Runtime($Manifest, [string]$Root, [string]$Package, [bool]$NoDownloadCache = $false) {
    $cacheRoots = @()
    if (-not $NoDownloadCache) { $cacheRoots = @("$env:APPDATA/.minecraft", "$env:USERPROFILE/.gradle/caches/fabric-loom") }
    Write-Host '[2/4] Download Java 25, Minecraft, Fabric, and assets' -ForegroundColor Cyan
    if ($NoDownloadCache) { Write-Host 'External download caches disabled. Fresh installations download every dependency.' }
    Get-Downloads $Manifest.downloads $Root $cacheRoots
    $javaDirectory = Join-Path $Root 'java'
    if (-not (Test-Path -LiteralPath "$javaDirectory/$($Manifest.javaHome)/bin/java.exe")) {
        Expand-Archive -LiteralPath "$Root/java.zip" -DestinationPath $javaDirectory -Force
    }
    $java = & "$PSScriptRoot/Resolve-LocalPath.ps1" -File "$javaDirectory/$($Manifest.javaHome)/bin/java.exe"
    $version = [IO.File]::ReadAllText("$javaDirectory/$($Manifest.javaHome)/release")
    if ($version -notmatch 'JAVA_VERSION="25\.' -or $version -notmatch 'OS_ARCH="(amd64|x86_64)"') { throw 'The downloaded Java runtime must be Java 25 for Windows x64.' }
    New-Item -ItemType Directory -Path "$Root/minecraft/mods", "$Root/settings", "$Root/worlds" -Force | Out-Null
    Copy-Item -LiteralPath "$Package/payload/minecraft/mods/garrycraft.jar" -Destination "$Root/minecraft/mods/garrycraft.jar" -Force
    $classpath = $Manifest.classpath -join ';'
    $mods = 'minecraft/mods/garrycraft.jar;minecraft/mods/fabric-api.jar'
    $values = @('-Xmx3G', '-Dstdout.encoding=UTF-8', '-Dstderr.encoding=UTF-8', '--enable-native-access=ALL-UNNAMED', '--add-exports', 'java.base/jdk.internal.misc=ALL-UNNAMED',
        '-XX:StackShadowPages=32', '-Dgarrycraft.autoWorld=true', "-Dfabric.addMods=$mods", '-cp', $classpath,
        $Manifest.mainClass, '--username', 'GarryCraft', '--version', $Manifest.minecraft,
        '--accessToken', '0', '--assetIndex', $Manifest.assetIndex, '--assetsDir', 'assets', '--versionType', 'release')
    $quoted = $values | ForEach-Object { '"' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }
    [IO.File]::WriteAllLines("$Root/java.args", [string[]]$quoted, (New-Object Text.UTF8Encoding($false)))
    foreach ($file in 'Runtime.ps1', 'RuntimeFiles.ps1', 'RuntimeProcess.ps1', 'Play.ps1', 'Uninstall.ps1', 'UninstallPaths.ps1', 'GameFiles.ps1', 'Resolve-LocalPath.ps1') {
        Copy-Item -LiteralPath "$PSScriptRoot/$file" -Destination "$Root/$file" -Force
    }
    Copy-Item -LiteralPath "$PSScriptRoot/Play.cmd.template" -Destination "$Root/Play.cmd" -Force
    Copy-Item -LiteralPath "$PSScriptRoot/Uninstall.cmd.template" -Destination "$Root/Uninstall.cmd" -Force
    $config = @{java=$java; worlds="$Root/worlds"; settings="$Root/settings"}
    [IO.File]::WriteAllText("$Root/config.json", ($config | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
