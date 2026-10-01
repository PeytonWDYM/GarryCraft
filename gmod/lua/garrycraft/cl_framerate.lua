local GC = GarryCraft
local saved
local savedNoFocus
local ceiling
local target
local average = 0
local lowSince
local nextCheck = 0
local nextProbe = 0
local peerAt = 0
local peerFrame = 0
local readyAt

concommand.Add("garrycraft_fps_reset", function()
    if not saved then return end
    target = ceiling
    average = 1 / ceiling
    lowSince = nil
    readyAt = RealTime() + 10
    nextProbe = readyAt + 8
    garrycraft_bridge.cap(GetConVar("fps_max"), target)
    garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), target)
end)

-- Both processes share one ceiling. Sustained slow frames lower it, and bounded probes permit recovery.
hook.Add("PreRender", "GarryCraftFrameTarget", function()
    local active = IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft")
    if not active then
        if saved then
            garrycraft_bridge.cap(GetConVar("fps_max"), saved)
            garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), savedNoFocus)
            saved = nil
        end
        return
    end
    local now = RealTime()
    if not saved then
        saved = GetConVar("fps_max"):GetFloat()
        savedNoFocus = GetConVar("fps_max_nofocus"):GetFloat()
        ceiling = garrycraft_bridge.refresh()
        target = ceiling
        average = 1 / ceiling
        nextProbe = now + 8
        readyAt = now + 10
        garrycraft_bridge.cap(GetConVar("fps_max"), target)
        garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), target)
    end
    average = Lerp(0.04, average, math.Clamp(RealFrameTime(), 0.001, 0.1))
    if GC.State and GC.State.frame ~= peerFrame then peerAt = now peerFrame = GC.State.frame end
    if now < nextCheck then return end
    nextCheck = now + 0.5
    local fps = 1 / average
    local peer = GC.State and GC.State.fps or 0
    if peer > 0 and now - peerAt < 1 and not GC.ScreenOpen and not gui.IsConsoleVisible()
        and GC.State.linked and now >= readyAt
        and GC.State.geometryReady then
        local slower = math.min(fps, peer)
        if slower < target * 0.8 then
            lowSince = lowSince or now
            if now - lowSince >= 3 then
                target = math.max(10, math.floor(slower / 5) * 5)
                lowSince = nil
                nextProbe = now + 8
            end
        else
            lowSince = nil
            if now >= nextProbe and slower >= target * 0.88 then
                target = math.min(ceiling, math.ceil(target * 1.1 / 5) * 5)
                nextProbe = now + 8
            end
        end
    end
    if gui.IsConsoleVisible() or not GC.State or not GC.State.linked then lowSince = nil end
    if GetConVar("fps_max"):GetFloat() ~= target then garrycraft_bridge.cap(GetConVar("fps_max"), target) end
    if GetConVar("fps_max_nofocus"):GetFloat() ~= target then garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), target) end
    GC.FrameStats = {source = fps, minecraft = peer, target = target, refresh = ceiling}
    net.Start("garrycraft_fps")
    net.WriteUInt(target, 16)
    net.SendToServer()
end)

hook.Add("ShutDown", "GarryCraftRestoreFrameCap", function()
    if saved then
        garrycraft_bridge.cap(GetConVar("fps_max"), saved)
        garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), savedNoFocus)
    end
end)
