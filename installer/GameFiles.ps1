# Steam records every library in libraryfolders.vdf. Do not search unrelated folders.
function Get-RunningGmod([string]$Game, [string]$Resolver = "$PSScriptRoot/Resolve-LocalPath.ps1") {
    $executable = Join-Path $Game 'bin\win64\gmod.exe'
    Get-Process gmod -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and (& $Resolver -File $_.Path) -eq $executable
    }
}

function Find-Gmod {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return }
    $libraries = @($steam)
    $vdf = Join-Path $steam 'steamapps/libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($match in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $libraries += $match.Groups[1].Value.Replace('\\', '\')
        }
    }
    foreach ($library in $libraries | ForEach-Object { [IO.Path]::GetFullPath($_) } | Sort-Object -Unique) {
        $game = Join-Path $library "steamapps/common/GarrysMod"
        if (Test-Path -LiteralPath "$game/bin/win64/gmod.exe") { $game }
    }
}

function Assert-Game([string]$Game, $Builds) {
    if (-not (Test-Path -LiteralPath "$Game/bin/win64/gmod.exe")) {
        throw "Cannot find bin\win64\gmod.exe in: $Game`nIn Steam, select Garry's Mod > Properties > Betas > x86-64.`nWait for the update. Then use Installed Files > Browse and select that folder."
    }
    if (-not (Test-Path -LiteralPath "$Game/garrysmod" -PathType Container)) { throw 'Select the GarrysMod folder that contains bin and garrysmod.' }
    foreach ($build in $Builds) {
        $path = Join-Path $Game $build.path
        $stream = [IO.File]::OpenRead($path)
        $reader = New-Object IO.BinaryReader($stream)
        try {
            if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Invalid engine file: $path" }
            $stream.Position = 0x3c
            $header = $reader.ReadUInt32()
            $stream.Position = $header
            if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw "The engine file is not Windows x64: $path" }
            $stream.Position = $header + 8
            $timestamp = $reader.ReadUInt32()
            $stream.Position = $header + 24 + 56
            $size = $reader.ReadUInt32()
            $stream.Position = $header + 24 + 64
            $checksum = $reader.ReadUInt32()
            if ($timestamp -ne $build.timestamp -or $size -ne $build.imageSize -or $checksum -ne $build.checksum) {
                throw "Unsupported engine build: $path`nGarryCraft V1 requires the engine builds in docs/INSTALL.md.`nSteam updates can change these files. Use a matching GarryCraft release. Do not replace game DLLs."
            }
        } finally { $reader.Dispose() }
    }
}

# Roll back all replaced files if any game copy fails. The runtime pointer is copied last.
function Install-GameFiles([string]$Manual, [string]$Game, [string]$Backup, $Paths) {
    $changed = New-Object 'Collections.Generic.List[object]'
    try {
        foreach ($relative in $Paths) {
            $destination = Join-Path $Game $relative
            $previous = Join-Path $Backup $relative
            $existed = Test-Path -LiteralPath $destination
            if ($existed) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $previous) -Force | Out-Null
                Copy-Item -LiteralPath $destination -Destination $previous
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            $changed.Add(@{destination=$destination; previous=$previous; existed=$existed})
            Copy-Item -LiteralPath (Join-Path $Manual $relative) -Destination $destination -Force
        }
    } catch {
        $failure = $_.Exception.Message
        for ($i = $changed.Count - 1; $i -ge 0; $i--) {
            $entry = $changed[$i]
            try {
                if ($entry.existed) { Copy-Item -LiteralPath $entry.previous -Destination $entry.destination -Force }
                elseif (Test-Path -LiteralPath $entry.destination) { Remove-Item -LiteralPath $entry.destination }
            } catch { Write-Warning "Restore this backup manually: $($entry.previous) -> $($entry.destination)" }
        }
        throw "Cannot install game files: $failure`nClose Garry's Mod and rerun Install.cmd. Previous files are in: $Backup"
    }
}

function Show-ManualCopy([string]$Root, [string]$Game) {
    Write-Host 'Manual copy (close Garry''s Mod first):' -ForegroundColor Yellow
    Write-Host "  $Root\manual\garrysmod\addons\garrycraft -> $Game\garrysmod\addons\garrycraft"
    Write-Host "  $Root\manual\garrysmod\lua\bin\gmcl_garrycraft_win64.dll -> $Game\garrysmod\lua\bin\gmcl_garrycraft_win64.dll"
    Write-Host "  $Root\manual\garrysmod\lua\bin\gmsv_garrycraft_win64.dll -> $Game\garrysmod\lua\bin\gmsv_garrycraft_win64.dll"
    Write-Host "  $Root\manual\garrysmod\data\garrycraft-runtime.json -> $Game\garrysmod\data\garrycraft-runtime.json"
    Write-Host "  $Root\manual\garrysmod\cfg\garrycraft-session.cfg -> $Game\garrysmod\cfg\garrycraft-session.cfg"
    Write-Host "Minecraft mods: $Root\minecraft\mods (already installed)"
    Write-Host "After all copies, open: $Root\Play.cmd"
}
