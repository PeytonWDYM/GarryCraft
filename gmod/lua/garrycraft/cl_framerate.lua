local GC = GarryCraft
local average = 1 / 240
local nextReport = 0
local frames = {}
local frameIndex = 0
local phases = {}
local previousFrame

garrycraft_bridge.cap(GetConVar("fps_max"), 240)
garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), 240)

-- Keep the requested ceiling fixed. A temporary slowdown must not lower both games' caps.
hook.Add("PreRender", "GarryCraftFrameTarget", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    local now = SysTime()
    local frame = previousFrame and now - previousFrame or 1 / 240
    previousFrame = now
    frameIndex = frameIndex + 1
    local index = (frameIndex - 1) % 25000 + 1
    frames[index] = frame * 1000
    phases[index] = GC.State and GC.State.parityPhase or "waiting"
    average = Lerp(0.04, average, frame)
    if GetConVar("fps_max"):GetInt() ~= 240 then garrycraft_bridge.cap(GetConVar("fps_max"), 240) end
    if GetConVar("fps_max_nofocus"):GetInt() ~= 240 then garrycraft_bridge.cap(GetConVar("fps_max_nofocus"), 240) end
    if RealTime() < nextReport then return end
    nextReport = RealTime() + 0.5
    GC.FrameStats = {source = 1 / average, minecraft = GC.State and GC.State.fps or 0, target = 240,
        refresh = garrycraft_bridge.refresh()}
    net.Start("garrycraft_fps")
    net.WriteUInt(240, 16)
    net.SendToServer()
end)

concommand.Add("garrycraft_fps_reset", function() frames = {} phases = {} frameIndex = 0 previousFrame = nil end)
local function summarize(values)
    local sorted = table.Copy(values)
    table.sort(sorted)
    local count = #sorted
    if count == 0 then return {count = 0} end
    return {count = count, p50 = sorted[math.ceil(count * .5)], p95 = sorted[math.ceil(count * .95)],
        p99 = sorted[math.ceil(count * .99)], maximum = sorted[count], stable240 = sorted[math.ceil(count * .99)] <= 1000 / 240}
end
concommand.Add("garrycraft_frame_report", function()
    local report = summarize(frames)
    report.frames, report.phases, report.summaries = frames, phases, {}
    local grouped = {}
    for index, phase in ipairs(phases) do
        grouped[phase] = grouped[phase] or {}
        grouped[phase][#grouped[phase] + 1] = frames[index]
    end
    for phase, values in pairs(grouped) do report.summaries[phase] = summarize(values) end
    file.Write("garrycraft-frame-times.json", util.TableToJSON(report))
end)
