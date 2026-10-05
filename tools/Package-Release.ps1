param([string]$OutputRoot = "$env:LOCALAPPDATA/GarryCraft/releases",
    [string]$JavaHome = "$env:LOCALAPPDATA/GarryCraft/tools/java/jdk-25.0.4.1+1")
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
& "$PSScriptRoot/Build.ps1" -JavaHome $JavaHome
$properties = Get-Content "$repository/fabric/gradle.properties" -Raw
$version = [regex]::Match($properties, '(?m)^version=(.+)').Groups[1].Value.Trim()
$stage = Join-Path $OutputRoot "GarryCraft-$version-windows-x64"
if (Test-Path -LiteralPath $stage) { throw "Use a new OutputRoot. The staging directory exists: $stage" }
New-Item -ItemType Directory -Path "$stage/payload/garrysmod/lua/bin", "$stage/payload/garrysmod/addons/garrycraft", "$stage/payload/minecraft/mods", "$stage/installer", "$stage/docs" -Force | Out-Null
foreach ($realm in 'gmcl','gmsv') {
    Copy-Item "$repository/native/build/Release/${realm}_garrycraft_win64.dll" "$stage/payload/garrysmod/lua/bin/"
}
Copy-Item "$repository/gmod/lua" "$stage/payload/garrysmod/addons/garrycraft/" -Recurse
Copy-Item "$repository/fabric/build/libs/garrycraft-$version.jar" "$stage/payload/minecraft/mods/garrycraft.jar"
Copy-Item "$repository/installer/*.ps1" "$stage/installer/"
Copy-Item "$repository/installer/*.template" "$stage/installer/"
foreach ($name in 'Runtime.ps1','RuntimeFiles.ps1','Resolve-LocalPath.ps1') { Copy-Item "$PSScriptRoot/$name" "$stage/installer/" }
foreach ($name in 'README.md','LICENSE','THIRD_PARTY_NOTICES.md','MODLOG.md','PARITY.md','AGENTS.md','Install.cmd','Play.cmd') { Copy-Item "$repository/$name" "$stage/" }
foreach ($name in 'INSTALL.md','ARCHITECTURE.md','RELEASING.md') { Copy-Item "$repository/docs/$name" "$stage/docs/" }
Copy-Item "$repository/docs/images" "$stage/docs/" -Recurse
New-Item -ItemType Directory -Path "$stage/protocol", "$stage/tests" -Force | Out-Null
Copy-Item "$repository/protocol/README.md" "$stage/protocol/"
foreach ($name in 'release-install.md','RESULTS.md','physics-blocks.md') { Copy-Item "$repository/tests/$name" "$stage/tests/" }
$build = Get-Content "$repository/fabric/build.gradle" -Raw
$minecraft = [regex]::Match($build, "minecraft 'com.mojang:minecraft:([^']+)'").Groups[1].Value
$loader = [regex]::Match($build, "implementation 'net.fabricmc:fabric-loader:([^']+)'").Groups[1].Value
$api = [regex]::Match($build, "implementation 'net.fabricmc.fabric-api:fabric-api:([^']+)'").Groups[1].Value
$downloads = New-Object 'Collections.Generic.List[object]'
$classpath = New-Object 'Collections.Generic.List[string]'
function Download($Url, $Path, $Hash, $Algorithm = 'SHA1') {
    $downloads.Add(@{url=$Url; path=$Path; hash=$Hash; algorithm=$Algorithm})
}
function Library-Path([string]$Name) {
    $parts = $Name.Split(':')
    $suffix = if ($parts.Count -eq 4) { "-$($parts[3])" } else { '' }
    "$($parts[0].Replace('.','/'))/$($parts[1])/$($parts[2])/$($parts[1])-$($parts[2])$suffix.jar"
}
$versions = Invoke-RestMethod 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
$entry = $versions.versions | Where-Object id -eq $minecraft
if (-not $entry) { throw "Minecraft $minecraft is missing from Mojang's manifest." }
$mc = Invoke-RestMethod $entry.url
Download $mc.downloads.client.url "versions/$minecraft/client.jar" $mc.downloads.client.sha1
$profile = Invoke-RestMethod "https://meta.fabricmc.net/v2/versions/loader/$minecraft/$loader/profile/json"
$fabricNames = @()
foreach ($library in $profile.libraries) {
    $path = Library-Path $library.name
    $url = "$($library.url)$path"
    $sha1 = if ($library.sha1) { $library.sha1 } else { ([string](Invoke-RestMethod "$url.sha1")).Trim() }
    Download $url "libraries/$path" $sha1
    $classpath.Add("libraries/$path")
    $fabricNames += ($library.name.Split(':')[0..1] -join ':')
}
foreach ($library in $mc.libraries) {
    $allowed = -not $library.rules
    foreach ($rule in $library.rules) {
        $matches = (-not $rule.os.name -or $rule.os.name -eq 'windows') -and
            (-not $rule.os.arch -or $rule.os.arch -in 'x86_64','amd64','x64')
        if ($matches) { $allowed = $rule.action -eq 'allow' }
    }
    if (-not $allowed -or ($library.name.Split(':')[0..1] -join ':') -in $fabricNames) { continue }
    $artifact = $library.downloads.artifact
    Download $artifact.url "libraries/$($artifact.path)" $artifact.sha1
    $classpath.Add("libraries/$($artifact.path)")
}
$classpath.Add("versions/$minecraft/client.jar")
$apiUrl = "https://maven.fabricmc.net/net/fabricmc/fabric-api/fabric-api/$api/fabric-api-$api.jar"
Download $apiUrl 'minecraft/mods/fabric-api.jar' ([string](Invoke-RestMethod "$apiUrl.sha1")).Trim()
Download $mc.assetIndex.url "assets/indexes/$($mc.assetIndex.id).json" $mc.assetIndex.sha1
$assets = Invoke-RestMethod $mc.assetIndex.url
foreach ($property in $assets.objects.PSObject.Properties) {
    $hash = $property.Value.hash
    $path = "$($hash.Substring(0,2))/$hash"
    Download "https://resources.download.minecraft.net/$path" "assets/objects/$path" $hash
}
# Record the exact Java archive and checksum in each release, even if newer Java 25 builds appear later.
$java = @(Invoke-RestMethod 'https://api.adoptium.net/v3/assets/latest/25/hotspot?architecture=x64&image_type=jre&os=windows')[0]
Download $java.binary.package.link 'java.zip' $java.binary.package.checksum 'SHA256'
$javaHomeName = "$($java.release_name)-jre"
$payload = @(Get-ChildItem "$stage/payload" -File -Recurse | Sort-Object FullName | ForEach-Object {
    @{path=$_.FullName.Substring("$stage/payload".Length + 1).Replace('\','/'); sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash}
})
# Read the same PE identifiers that guard the compiled native adapters.
$sdk = Get-Content "$repository/native/src/sdkcompat.hpp" -Raw
$engineBuilds = @([regex]::Matches($sdk, 'matchesBuild\((?:GetModuleHandleW\(L"([^"]+)"\)|module), (0x[0-9a-f]+), (0x[0-9a-f]+), (0x[0-9a-f]+)\)') | ForEach-Object {
    $name = $_.Groups[1].Value
    if (-not $name) {
        $prefix = $sdk.Substring(0, $_.Index)
        $modules = [regex]::Matches($prefix, 'auto module = GetModuleHandleW\(L"([^"]+)"\)')
        $name = $modules[$modules.Count - 1].Groups[1].Value
    }
    @{path="bin/win64/$name"; timestamp=[Convert]::ToUInt32($_.Groups[2].Value.Substring(2),16);
        imageSize=[Convert]::ToUInt32($_.Groups[3].Value.Substring(2),16); checksum=[Convert]::ToUInt32($_.Groups[4].Value.Substring(2),16)}
})
if ($engineBuilds.Count -ne 4) { throw 'Expected four native engine build guards.' }
$manifest = @{version=$version; commit=(git -C $repository rev-parse HEAD); minecraft=$minecraft; loader=$loader; api=$api;
    javaHome=$javaHomeName; assetIndex=$mc.assetIndex.id; mainClass=$profile.mainClass;
    payload=$payload; downloads=@($downloads.ToArray() | Sort-Object -Property path -Unique); classpath=@($classpath.ToArray()); engineBuilds=$engineBuilds}
$manifest | ConvertTo-Json -Depth 8 | Set-Content "$stage/release.json" -Encoding utf8NoBOM
$zip = "$stage.zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip
"$((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower())  $([IO.Path]::GetFileName($zip))" |
    Set-Content "$zip.sha256" -Encoding ascii
Write-Output "Release: $zip"
Write-Output "Checksum: $zip.sha256"
$notes = Join-Path $OutputRoot "GarryCraft-$version-release-notes.md"
([IO.File]::ReadAllText("$repository/docs/RELEASE_NOTES.md")).Replace('{version}', $version) |
    Set-Content -LiteralPath $notes -Encoding utf8NoBOM
Write-Output "Release notes: $notes"
