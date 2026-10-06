# Resolve installed paths from setup records, not from the ZIP's current location.
function Find-PlayerInstallation([string]$Package, [string]$Root, [string]$Game) {
    if (-not $Root -and $Package -and (Test-Path -LiteralPath "$Package/player.json")) {
        $Root = (Get-Content -LiteralPath "$Package/player.json" -Raw -Encoding UTF8 | ConvertFrom-Json).root
    }
    if (-not $Root) {
        $games = if ($Game) { @($Game) } else { @(Find-Gmod) }
        $players = @(foreach ($candidate in $games) {
            $pointer = "$candidate/garrysmod/data/garrycraft-runtime.json"
            if (Test-Path -LiteralPath $pointer) {
                [pscustomobject]@{root=(Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json).root; game=$candidate}
            }
        })
        if ($players.Count -gt 1) { throw 'Multiple GarryCraft installations found. Rerun Uninstall.cmd with -GmodPath or -InstallRoot.' }
        if ($players.Count -eq 1) { $Root = $players[0].root; $Game = $players[0].game }
        else { $Root = "$env:LOCALAPPDATA/GarryCraft/player" }
    }
    $Root = [IO.Path]::GetFullPath($Root)
    if (Test-Path -LiteralPath $Root) {
        if (-not (Test-Path -LiteralPath "$Root/.garrycraft-player") -or (Get-Content -LiteralPath "$Root/.garrycraft-player" -Raw).Trim() -ne 'GarryCraft player installation') {
            throw "This directory is not an owned GarryCraft player installation: $Root"
        }
        $Root = Split-Path -Parent (& $resolver -File "$Root/.garrycraft-player")
        Assert-NoRedirect $Root
        if (-not $Game -and (Test-Path -LiteralPath "$Root/install.json")) { $Game = (Get-Content -LiteralPath "$Root/install.json" -Raw -Encoding UTF8 | ConvertFrom-Json).game }
    }
    if (-not $Game -or -not (Test-Path -LiteralPath "$Game/bin/win64/gmod.exe")) {
        foreach ($candidate in Find-Gmod) {
            $pointer = "$candidate/garrysmod/data/garrycraft-runtime.json"
            if ((Test-Path -LiteralPath $pointer) -and [IO.Path]::GetFullPath((Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json).root) -eq $Root) { $Game = $candidate; break }
        }
    }
    if ($Game -and -not (Test-Path -LiteralPath $Game)) {
        Write-Host "The recorded game folder is absent. Removing only the player installation: $Game"
        $Game = $null
    }
    if ($Game) {
        $Game = [IO.Path]::GetFullPath($Game)
        if (Test-Path -LiteralPath "$Game/bin/win64/gmod.exe") {
            $Game = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (& $resolver -File "$Game/bin/win64/gmod.exe")))
            if (-not (Test-Path -LiteralPath "$Game/garrysmod" -PathType Container)) { throw 'Select the outer GarrysMod folder.' }
        } else { throw "Garry's Mod moved or was removed. Supply its current outer folder with -GmodPath: $Game" }
    }
    if ($Root -eq [IO.Path]::GetPathRoot($Root) -or ($Package -and $Root -eq [IO.Path]::GetFullPath($Package)) -or
        ($Game -and ($Root -eq $Game -or $Game.StartsWith("$Root\", [StringComparison]::OrdinalIgnoreCase)))) {
        throw "Refusing to remove a game, package, or drive root: $Root"
    }
    return [pscustomobject]@{root=$Root;game=$Game}
}

# Recursive deletion must never traverse a junction or another directory redirect.
function Assert-NoRedirect([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Remove the directory redirect before uninstalling: $Path" }
    if ($item.PSIsContainer -and (Get-ChildItem -LiteralPath $Path -Force -Recurse -Attributes ReparsePoint)) {
        throw "Remove directory redirects inside this installation before uninstalling: $Path"
    }
}

function Get-UninstallGameTargets([string]$Game, [string]$Root) {
    if (-not $Game) { return }
    $pointer = "$Game/garrysmod/data/garrycraft-runtime.json"
    if (Test-Path -LiteralPath $pointer) {
        $owner = [IO.Path]::GetFullPath((Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json).root)
        if ($owner -ne $Root) { Write-Host 'Another player installation owns this game. Its game files remain.'; return }
    }
    $paths = @("$Game/garrysmod/addons/garrycraft", "$Game/garrysmod/cfg/garrycraft-session.cfg", "$Game/garrysmod/lua/bin/gmcl_garrycraft_win64.dll", "$Game/garrysmod/lua/bin/gmsv_garrycraft_win64.dll")
    if (Test-Path -LiteralPath "$Game/garrysmod/data") {
        $paths += @(Get-ChildItem -LiteralPath "$Game/garrysmod/data" -Force | Where-Object { $_.Name -like 'garrycraft-*' } | ForEach-Object FullName)
    }
    foreach ($path in $paths) {
        $target = [IO.Path]::GetFullPath($path)
        if (-not $target.StartsWith("$Game\garrysmod\", [StringComparison]::OrdinalIgnoreCase)) { throw "Invalid game cleanup path: $target" }
        if (Test-Path -LiteralPath $target) {
            $ancestor = $target
            while ($ancestor -ne $Game) {
                if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Redirected game cleanup path: $ancestor" }
                $ancestor = Split-Path -Parent $ancestor
            }
            Assert-NoRedirect $target
            $target
        }
    }
}

# Check every selected file before deletion so a loaded or locked DLL causes no partial uninstall.
function Assert-Unlocked($Targets) {
    foreach ($target in $Targets) {
        foreach ($file in Get-ChildItem -LiteralPath $target -File -Recurse -Force) {
            try { $stream = [IO.File]::Open($file.FullName, 'Open', 'Read', 'None'); $stream.Dispose() }
            catch { throw "Close Garry's Mod and Minecraft, then rerun Uninstall.cmd. A file is locked or inaccessible: $($file.FullName)" }
        }
    }
}
