function Prepare-Runtime($Manifest, [string]$Root, [string]$Package) {
    $cacheRoots = @("$env:APPDATA/.minecraft", "$env:USERPROFILE/.gradle/caches/fabric-loom")
    Write-Host '[2/4] Download Java 25, Minecraft, Fabric, and assets' -ForegroundColor Cyan
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
    $classpath = @($Manifest.classpath | ForEach-Object { Join-Path $Root $_ }) -join ';'
    $mods = "$Root/minecraft/mods/garrycraft.jar;$Root/minecraft/mods/fabric-api.jar"
    $values = @('-Xmx3G', '--enable-native-access=ALL-UNNAMED', '--add-exports', 'java.base/jdk.internal.misc=ALL-UNNAMED',
        '-XX:StackShadowPages=32', '-Dgarrycraft.autoWorld=true', "-Dfabric.addMods=$mods", '-cp', $classpath,
        $Manifest.mainClass, '--username', 'GarryCraft', '--version', $Manifest.minecraft,
        '--accessToken', '0', '--assetIndex', $Manifest.assetIndex, '--assetsDir', "$Root/assets", '--versionType', 'release')
    $quoted = $values | ForEach-Object { '"' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }
    [IO.File]::WriteAllLines("$Root/java.args", [string[]]$quoted, (New-Object Text.UTF8Encoding($false)))
    foreach ($file in 'Runtime.ps1', 'RuntimeFiles.ps1', 'Play.ps1') {
        Copy-Item -LiteralPath "$PSScriptRoot/$file" -Destination "$Root/$file" -Force
    }
    Copy-Item -LiteralPath "$PSScriptRoot/Play.cmd" -Destination "$Root/Play.cmd" -Force
    $config = @{java=$java; worlds="$Root/worlds"; settings="$Root/settings"}
    [IO.File]::WriteAllText("$Root/config.json", ($config | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
}
