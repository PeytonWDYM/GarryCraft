param([Parameter(Mandatory)][string]$LabPath, [Parameter(Mandatory)][string]$RunRoot)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath "$LabPath/.garrycraft-lab")) { throw 'Use a marked game installation.' }
if (Get-Process gmod -ErrorAction SilentlyContinue) { throw 'Close GMod before this test.' }
if (Test-Path -LiteralPath $RunRoot) { throw 'Use a new result directory.' }
$LabPath = [IO.Path]::GetFullPath($LabPath)
$RunRoot = [IO.Path]::GetFullPath($RunRoot)
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$probe = "$LabPath/garrysmod/addons/launch-isolation-probe/lua/autorun/launch_isolation_probe.lua"
New-Item -ItemType Directory -Path (Split-Path -Parent $probe) -Force | Out-Null
$id = [DateTime]::Now.ToString('yyyyMMddHHmmss')
@"
if SERVER then AddCSLuaFile() end
hook.Add('InitPostEntity','LaunchIsolationProbe',function()
    timer.Simple(5,function()
        local owner = SERVER and player.GetHumans()[1] or LocalPlayer()
        local hooks = 0
        for _, callbacks in pairs(hook.GetTable()) do
            for name in pairs(callbacks) do if isstring(name) and string.find(name,'GarryCraft',1,true) then hooks = hooks + 1 end end
        end
        file.Write('launch-isolation-$id-' .. (SERVER and 'server' or 'client') .. '.json',util.TableToJSON({
            bridgeLoaded=garrycraft_bridge~=nil, addonActive=GarryCraft~=nil, hooks=hooks,
            singlePlayer=game.SinglePlayer(), playerAttached=IsValid(owner) and owner:GetNWBool('GarryCraft'),
            movement=IsValid(owner) and owner:GetMoveType(), weapon=IsValid(owner) and IsValid(owner:GetActiveWeapon()) and owner:GetActiveWeapon():GetClass()
        }))
    end)
end)
"@ | Set-Content -LiteralPath $probe -Encoding ascii
$game = $null
try {
    # Include the old archived switch: ordinary launch must ignore it.
    Add-Content -LiteralPath "$LabPath/garrysmod/cfg/config.cfg" -Value 'garrycraft_enabled "1"'
    $start = New-Object Diagnostics.ProcessStartInfo("$LabPath/bin/win64/gmod.exe", '-insecure -novid -condebug -windowed -w 1920 -h 1080 +sv_lan 1 +maxplayers 1')
    $start.WorkingDirectory = $LabPath
    $start.UseShellExecute = $false
    $game = [Diagnostics.Process]::Start($start)
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do { Start-Sleep -Seconds 1; $game.Refresh() } until (($game.MainWindowHandle -ne 0 -and $game.Responding) -or [DateTime]::UtcNow -gt $deadline)
    if ($game.MainWindowHandle -eq 0 -or -not $game.Responding) { throw 'The test game did not reach its menu.' }
    Start-Sleep -Seconds 5
    & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'map gm_construct'
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do { Start-Sleep -Seconds 1 } until (((Test-Path -LiteralPath "$LabPath/garrysmod/data/launch-isolation-$id-server.json") -and (Test-Path -LiteralPath "$LabPath/garrysmod/data/launch-isolation-$id-client.json")) -or [DateTime]::UtcNow -gt $deadline)
    $server = Get-Content -LiteralPath "$LabPath/garrysmod/data/launch-isolation-$id-server.json" -Raw | ConvertFrom-Json
    $client = Get-Content -LiteralPath "$LabPath/garrysmod/data/launch-isolation-$id-client.json" -Raw | ConvertFrom-Json
    $modules = @((Get-Process -Id $game.Id).Modules | ForEach-Object ModuleName)
    $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($game.Id)").CommandLine
    $checks = [ordered]@{
        normalCommandLine=$commandLine -notmatch 'garrycraft_session'
        serverInactive=-not $server.addonActive -and -not $server.bridgeLoaded
        clientInactive=-not $client.addonActive -and -not $client.bridgeLoaded
        noNativeModules=@($modules | Where-Object { $_ -match '^(gmcl|gmsv)_garrycraft_win64\.dll$' }).Count -eq 0
        noAddonHooks=$server.hooks -eq 0 -and $client.hooks -eq 0
        playerNormal=-not $server.playerAttached -and $server.movement -eq 2
        normalWeapon=$server.weapon -in 'weapon_physgun','weapon_physcannon','gmod_tool','weapon_pistol','weapon_crowbar'
    }
    $result = @{passed=-not ($checks.Values -contains $false); checks=$checks; server=$server; client=$client; modules=$modules; commandLine=$commandLine}
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$RunRoot/normal-launch-result.json"
    if (-not $result.passed) { throw 'Normal launch isolation failed.' }
    $checks | ConvertTo-Json
} finally {
    if ($game -and (Get-Process -Id $game.Id -ErrorAction SilentlyContinue)) {
        & "$PSScriptRoot/Send-LabCommand.ps1" -LabPath $LabPath -GamePid $game.Id -Command 'quit'
        $game.WaitForExit(30000) | Out-Null
    }
    Remove-Item -LiteralPath $probe
    if (Test-Path -LiteralPath "$LabPath/garrysmod/console.log") { Copy-Item -LiteralPath "$LabPath/garrysmod/console.log" -Destination "$RunRoot/source-console.log" }
}
