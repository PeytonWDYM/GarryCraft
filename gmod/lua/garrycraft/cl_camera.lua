local GC = GarryCraft
require("garrycraft")
local history = {}
local path
local lastFrame = 0
local delay = 0.012
local due = {}
local dueIndex = 1
local latest

-- Port of SkyCraft's raw-tick history. Both games read Windows' performance counter.
local function accept(state)
    latest = state
    GC.State = state
    local previous = history[#history]
    if previous and (previous.state.session ~= state.session or previous.state.instance ~= state.instance
        or previous.state.teleportAck ~= state.teleportAck
        or GC.ToSource(previous.state.x, previous.state.y, previous.state.z):DistToSqr(GC.ToSource(state.x, state.y, state.z)) > 256 * 256) then
        history = {}
        previous = nil
    end
    if previous and previous.state.tick == state.tick then return end
    local period = state.tickMs / 1000
    local at = state.tickTime
    if previous then
        local slots = math.floor((at - previous.at) / period + 0.5)
        local error = at - (previous.at + slots * period)
        if slots >= 1 and slots <= 10 and math.abs(error) < period * 0.3 then
            at = previous.at + slots * period + error / 16
        end
    end
    if lastFrame ~= 0 then
        local late = lastFrame - at
        if late < 0.03 then
            due[dueIndex] = late
            dueIndex = dueIndex % 40 + 1
        end
    end
    history[#history + 1] = {at = at, state = state}
    if #history > 8 then table.remove(history, 1) end
end

hook.Add("PreRender", "GarryCraftNativeCamera", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:GetNWBool("GarryCraft") then history = {} latest = nil path = nil return end
    local bridge = player:GetNWString("GarryCraftBridge")
    if bridge == "" then return end
    if path ~= bridge then garrycraft_bridge.open(bridge) path = bridge history = {} end
    local payload = garrycraft_bridge.receive(1)
    if payload then
        local state = util.JSONToTable(payload)
        if state.linked and not state.reference and state.session == player:GetNWString("GarryCraftSession")
            and player:Alive() and state.teleportAck == player:GetNWInt("GarryCraftTeleport") then accept(state) end
    end
end)

hook.Add("CalcView", "GarryCraftCamera", function(player, origin, angles, fov)
    if not player:GetNWBool("GarryCraft") or #history == 0 then return end
    if not player:Alive() or latest.teleportAck ~= player:GetNWInt("GarryCraftTeleport") then return end
    local now = garrycraft_bridge.clock()
    if lastFrame ~= 0 and #due > 0 then
        local worst = -math.huge
        for _, late in ipairs(due) do worst = math.max(worst, late) end
        local target = math.Clamp(worst + 0.001, 0.004, 0.03)
        local dt = math.min(now - lastFrame, 0.1)
        delay = target > delay and math.min(target, delay + 0.02 * dt) or math.max(target, delay - 0.002 * dt)
    end
    lastFrame = now
    local renderAt = now - delay
    local index = 1
    for candidate = #history, 1, -1 do
        if history[candidate].at <= renderAt then index = candidate break end
    end
    local tick = history[index]
    local state = tick.state
    local period = state.tickMs / 1000
    local ticks = (renderAt - tick.at) / period
    local fraction = math.Clamp(ticks, 0, 1)
    local position = GC.ToSource(Lerp(fraction, state.prevX, state.x), Lerp(fraction, state.prevY, state.y), Lerp(fraction, state.prevZ, state.z))
    local eye = Lerp(fraction, state.eyePrevious, state.eye)
    if ticks > 1 and history[index + 1] then
        local following = history[index + 1]
        local gap = following.at - tick.at - period
        local part = gap > 0 and math.Clamp((renderAt - tick.at - period) / gap, 0, 1) or 1
        position = GC.ToSource(Lerp(part, state.x, following.state.prevX), Lerp(part, state.y, following.state.prevY), Lerp(part, state.z, following.state.prevZ))
        eye = Lerp(part, state.eye, following.state.eyePrevious)
    end
    GC.RenderFeet = position
    position = position + Vector(0, 0, eye * 32)
    local phase = -(state.walk + (state.walk - state.walkPrevious) * fraction) * math.pi
    local amount = Lerp(fraction, state.bobPrevious, state.bob)
    position = position - angles:Right() * math.sin(phase) * amount * 16 + angles:Up() * math.abs(math.cos(phase) * amount) * 32
    local viewAngles = Angle(angles.p - math.abs(math.cos(phase - 0.2) * amount) * 5, angles.y, angles.r + math.sin(phase) * amount * 3)
    local vertical = math.Clamp(latest.fov, 10, 170)
    local hostFov = math.deg(2 * math.atan(math.tan(math.rad(vertical) / 2) * 4 / 3))
    if latest.camera and latest.camera > 0 then
        local direction = latest.camera == 1 and -1 or 1
        local trace = util.TraceHull({start = position, endpos = position + angles:Forward() * 128 * direction,
            mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4),
            filter = function(entity) return entity ~= player and entity:GetOwner() ~= player end, mask = MASK_SOLID})
        position = trace.HitPos
        if latest.camera == 2 then viewAngles = Angle(-angles.p, angles.y + 180, 0) end
    end
    GC.ViewOrigin, GC.ViewAngles = position, viewAngles
    return {origin = position, angles = viewAngles, fov = hostFov, drawviewer = latest.camera and latest.camera > 0}
end)
