-- Same stationary pole, three camera poses, and independent off/on pixel pairs at production opacity.
-- Failures: a missing shadow, a shadow that moves with the camera, self-shadow acne, or stale resources after disable.
assert(CLIENT and game.SinglePlayer() and GarryCraft.State.linked, "Use an owned linked single-player lab")
local GC = GarryCraft
local previous = hook.GetTable().CalcView.GarryCraftCamera
local hands = hook.GetTable().PostDrawTranslucentRenderables.GarryCraftHands
local hud = hook.GetTable().HUDPaint.GarryCraftMinecraftOverlay
local saved = GetConVar("garrycraft_sun_shadows"):GetString()
-- Keep HDR adaptation from changing unrelated pixels between the paired captures.
local savedTone = GetConVar("mat_force_tonemap_scale"):GetString()
local run = {session = GC.State.session, samples = {}, points = {}}
local sun = util.GetSunInfo().direction:GetNormalized()
-- Captured RGB is gamma encoded. A five-percent irradiance change is about a two-percent RGB change.
local minimumLinearDrop = .05
for z = 0, 30 do for x = 0, 30 do
    local point = GC.ToSource(43.5 + x / 6, 10, -10.5 + z / 6)
    local trace = util.TraceLine({start = point, endpos = point - Vector(0,0,512), mask = MASK_SOLID_BRUSHONLY})
    assert(trace.Hit and trace.HitNormal.z > .9, "The pole needs a flat native receiver")
    point = trace.HitPos + Vector(0,0,.04)
    local receiver = assert(garrycraft_bridge.source_lightmaps_receiver_at(point), "The floor needs a verified lightmap receiver")
    local baseline, removed = 0, 0
    -- Predict the filtered footprint from real Source luxel positions and independent Minecraft rays.
    for _, tap in ipairs(receiver.taps) do
        local start = tap.position + tap.normal * receiver.receiver_offset
        local voxel = GC.VoxelLight(start)
        local sky, block = voxel and voxel.skyBrightnessInterpolated or 1, voxel and voxel.blockBrightnessInterpolated or 0
        local baked = .2126*tap.original.x + .7152*tap.original.y + .0722*tap.original.z
        baseline = baseline + tap.weight * (baked * sky + block * (.2126 + .7152*.87 + .0722*.67))
        if garrycraft_bridge.light_occluded(start, start + sun * 2048) then
            removed = removed + tap.weight * baked * sky * .35 * math.max(0,tap.normal:Dot(sun))
        end
    end
    local drop = baseline > 0 and removed / baseline or 0
    run.points[#run.points+1] = {position = point, expected = drop >= minimumLinearDrop,
        boundary = drop > .005 and drop < minimumLinearDrop, predictedDrop = drop, receiver = receiver}
end end
local expectedCount = 0
for _, point in ipairs(run.points) do if point.expected then expectedCount = expectedCount + 1 end end
assert(expectedCount > 20, "The exported pole must occlude the fixed receiver samples before capture")
hook.Remove("PostDrawTranslucentRenderables", "GarryCraftHands")
hook.Remove("HUDPaint", "GarryCraftMinecraftOverlay")
hook.Add("PreDrawViewModel", "GarryCraftDirectionalHideViewmodel", function() return true end)
RunConsoleCommand("mat_force_tonemap_scale", "1")
local views = {
    {name = "fixed", position = GC.ToSource(46,9,-8), angles = Angle(80,-180,0)},
    {name = "rotate", position = GC.ToSource(46,9,-8), angles = Angle(80,-150,0)},
    {name = "walk", position = GC.ToSource(47,9,-8), angles = Angle(80,-180,0)}}
local index, shadow, ready = 1, false, RealTime() + .7
RunConsoleCommand("garrycraft_sun_shadows", "0")
hook.Add("CalcView", "GarryCraftCamera", function()
    local view = views[index]
    GC.ViewOrigin, GC.ViewAngles = view.position, view.angles
    return {origin = view.position, angles = view.angles, fov = 90, drawviewer = false}
end)
local function finish(completed)
    hook.Add("CalcView", "GarryCraftCamera", previous)
    hook.Add("PostDrawTranslucentRenderables", "GarryCraftHands", hands)
    hook.Add("HUDPaint", "GarryCraftMinecraftOverlay", hud)
    hook.Remove("PreDrawViewModel", "GarryCraftDirectionalHideViewmodel")
    hook.Remove("PostRender", "GarryCraftDirectionalShadowTest")
    RunConsoleCommand("mat_force_tonemap_scale", savedTone)
    RunConsoleCommand("garrycraft_sun_shadows", saved)
    run.completed = completed
    file.Write("garrycraft-directional-shadows.json", util.TableToJSON(run, true))
    GC.DirectionalShadowTest = nil
end
GC.DirectionalShadowTest = {Finish = finish}
hook.Add("PostRender", "GarryCraftDirectionalShadowTest", function()
    if RealTime() < ready or GC.VoxelLightingReport().lightmaps.pending_receivers ~= 0 then return end
    render.CapturePixels()
    local values = {}
    for _, point in ipairs(run.points) do
        local screen = point.position:ToScreen()
        local hidden = garrycraft_bridge.light_occluded(point.position, GC.ViewOrigin)
            or util.TraceLine({start = GC.ViewOrigin, endpos = point.position, mask = MASK_SOLID_BRUSHONLY}).Hit
        if not point.boundary and not hidden and screen.visible and screen.x >= 0 and screen.x < ScrW() and screen.y >= 0 and screen.y < ScrH() then
            local r,g,b = render.ReadPixel(math.floor(screen.x),math.floor(screen.y))
            values[#values+1] = .2126*r+.7152*g+.0722*b
        else values[#values+1] = -1 end
    end
    local name = views[index].name .. (shadow and "-on" or "-off")
    file.CreateDir("garrycraft-directional")
    local path = "garrycraft-directional/" .. name .. ".png"
    file.Write(path,render.Capture({format="png",x=0,y=0,w=ScrW(),h=ScrH(),alpha=false}))
    run.samples[name] = {pixels = values, view = tostring(GC.ViewOrigin), angles = tostring(GC.ViewAngles), screenshot = path,
        tone = tostring(render.GetToneMappingScaleLinear()), sun = GC.SunReport(), voxels = GC.VoxelLightingReport()}
    if not shadow then shadow = true RunConsoleCommand("garrycraft_sun_shadows", "1")
    elseif index == #views then finish(true) return
    else index = index+1 shadow = false RunConsoleCommand("garrycraft_sun_shadows", "0") end
    ready = RealTime() + .7
end)
