local GC = GarryCraft
local enabled = CreateConVar("garrycraft_enabled", "1", FCVAR_ARCHIVE, "Start GarryCraft when entering a single-player map")
local request
local configuration
local startingAt
local nextPoll = 0
local attached = false
local failed = false
util.AddNetworkString("garrycraft_toggle")

local function status(message) SetGlobalString("GarryCraftStatus", message) end
local function publish()
    if request then file.Write("garrycraft-runtime-request.json", util.TableToJSON(request)) end
end
local function disable()
    if request then request.enabled = false publish() end
    GC.Stop()
    attached, startingAt = false, nil
    status("GarryCraft is off")
end
local function begin()
    if not game.SinglePlayer() then status("GarryCraft requires single-player") return end
    if file.Exists("garrycraft-runtime-manual.txt", "DATA") then status("Manual test launcher is active") return end
    local source = file.Read("garrycraft-runtime.json", "DATA")
    configuration = source and util.JSONToTable(source)
    if not configuration then
        failed = true
        status("Run tools/Setup-Lab.ps1 once to prepare Minecraft")
        return
    end
    failed = false
    request = {id = game.GetMap() .. ":" .. tostring(SysTime()), enabled = true, map = game.GetMap()}
    publish()
    local ok, message = pcall(garrycraft_bridge.runtime_start, configuration.root)
    if not ok then failed = true status(message) return end
    startingAt = RealTime()
    status("Starting Minecraft")
end
local function toggle(value)
    RunConsoleCommand("garrycraft_enabled", value and "1" or "0")
end
net.Receive("garrycraft_toggle", function(_, caller)
    if game.SinglePlayer() then
        local value = net.ReadBool()
        toggle(value)
        if value and enabled:GetBool() and failed then begin() end
    end
end)
concommand.Add("garrycraft_enable", function() toggle(true) if enabled:GetBool() and failed then begin() end end)
concommand.Add("garrycraft_disable", function() toggle(false) disable() end)
concommand.Add("garrycraft_stop", function() toggle(false) disable() end)
cvars.AddChangeCallback("garrycraft_enabled", function(_, _, value)
    if tonumber(value) == 0 then disable() else begin() end
end, "GarryCraftRuntime")

hook.Add("InitPostEntity", "GarryCraftAutoStart", function()
    if enabled:GetBool() then begin() else status("GarryCraft is off") end
end)
hook.Add("Think", "GarryCraftRuntime", function()
    if not request or RealTime() < nextPoll then return end
    nextPoll = RealTime() + 1
    publish() -- The helper stops Minecraft after a lost map heartbeat or host crash.
    if not request.enabled or failed then return end
    local contents = file.Read("garrycraft-runtime-status.json", "DATA")
    local state = contents and util.JSONToTable(contents)
    if state and state.id == request.id then
        if state.state == "error" then failed = true disable() status(state.message) return end
        if state.state == "ready" and not attached then
            local owner = player.GetHumans()[1]
            if IsValid(owner) then
                GetConVar("garrycraft_bridge"):SetString(configuration.root .. "/worlds/" .. game.GetMap() .. "/bridge.bin")
                -- Wait until the current hook has finished before changing player ownership.
                timer.Simple(0, function()
                    if not request.enabled then return end
                    local ok, message = pcall(GC.Start, owner)
                    if not ok then failed = true disable() status("Cannot load map collision: " .. message) return end
                    attached, startingAt = true, nil
                    status("Loading map collision")
                end)
            end
        elseif not attached then status(state.message) end
    end
    if attached and not GC.IsActive() then failed = true disable() status("Minecraft stopped responding. Select Enable to retry.") end
    if attached and GC.IsLinked() then status("GarryCraft is on") end
    if startingAt and RealTime() - startingAt > 120 then
        failed = true disable() status("Minecraft startup timed out. Read the map's launch logs.")
    end
end)
hook.Add("ShutDown", "GarryCraftRuntimeStop", disable)
