-- Load on the client of an owned, fresh single-player lab after building the fixture.
-- Failures: camera rotation translates the sun, walking shifts a fixed pole shadow,
-- a sealed room leaves Minecraft walls, a native prop, or its BSP floor bright,
-- an outside torch leaks through walls, or an inside torch fails to illuminate each receiver.
-- Repeat at production brightness. Remove the roof, then replace it and remove the torch.
-- Save same-pose PNGs and receiver pixels, not only exposure or draw counters.
-- An open alcove must receive propagated sky light. Roof transmission must follow
-- Minecraft material dampening for clear glass, tinted glass, and water.
assert(game.SinglePlayer() and GarryCraft.State.linked, "Use an owned linked single-player lab")
local GC = GarryCraft
local camera = hook.GetTable().CalcView.GarryCraftCamera
local hands = hook.GetTable().PostDrawTranslucentRenderables.GarryCraftHands
local hud = hook.GetTable().HUDPaint.GarryCraftMinecraftOverlay
hook.Remove("PostDrawTranslucentRenderables", "GarryCraftHands")
hook.Remove("HUDPaint", "GarryCraftMinecraftOverlay")
hook.Add("PreDrawViewModel", "GarryCraftReceiverHideViewmodel", function() return true end)
local origin, angles = GC.ToSource(37.5, 3.62, .5), Angle(15, -180, 0)
local pending
local savedTone = GetConVar("mat_force_tonemap_scale"):GetString()
local savedSun = GetConVar("garrycraft_sun_shadows"):GetString()
RunConsoleCommand("mat_force_tonemap_scale", "1")
local probePoints = {crate = GC.ToSource(35.5,3.5,1.5), floor = GC.ToSource(35.5,2.501,-.5), wall = GC.ToSource(35.001,3.5,-1.5)}
GC.ReceiverTest = {}
function GC.ReceiverTest.View(position, look)
    origin, angles = position, look
    hook.Add("CalcView", "GarryCraftCamera", function()
        GC.ViewOrigin, GC.ViewAngles = origin, angles
        return {origin = origin, angles = angles, fov = 70, drawviewer = false}
    end)
end
function GC.ReceiverTest.Capture(name)
    pending = name
end
function GC.ReceiverTest.Finish()
    hook.Add("CalcView", "GarryCraftCamera", camera)
    hook.Add("PostDrawTranslucentRenderables", "GarryCraftHands", hands)
    hook.Add("HUDPaint", "GarryCraftMinecraftOverlay", hud)
    hook.Remove("PreDrawViewModel", "GarryCraftReceiverHideViewmodel")
    hook.Remove("PostRender", "GarryCraftReceiverTest")
    GC.ReceiverTest = nil
    RunConsoleCommand("mat_force_tonemap_scale", savedTone)
    RunConsoleCommand("garrycraft_sun_shadows", savedSun)
end
hook.Add("PostRender", "GarryCraftReceiverTest", function()
    if not pending or GC.VoxelLightingReport().lightmaps.pending_receivers ~= 0
        or GC.DisplacementLightingReport().pending ~= 0 then return end
    local name = pending
    pending = nil
    render.CapturePixels()
    local pixels = {}
    for y = 1, 36 do for x = 1, 64 do
        local r, g, b = render.ReadPixel(math.floor(ScrW() * x / 65), math.floor(ScrH() * y / 37))
        pixels[#pixels + 1] = {r, g, b}
    end end
    file.CreateDir("garrycraft-receivers")
    local prefix = "garrycraft-receivers/" .. name
    local receivers = {}
    for label, point in pairs(probePoints) do
        local screen = point:ToScreen()
        local r,g,b = render.ReadPixel(math.floor(screen.x), math.floor(screen.y))
        receivers[label] = {position = tostring(point), screen = screen, luminance = .2126*r+.7152*g+.0722*b,
            transport = GC.VoxelLight(point)}
    end
    local floor = probePoints.floor
    local floorTrace = util.TraceLine({start = floor + Vector(0,0,8), endpos = floor - Vector(0,0,8), mask = MASK_SOLID_BRUSHONLY})
    receivers.floor.nativeSurface = floorTrace.HitWorld and floorTrace.HitPos:DistToSqr(floor) < 1
        and not garrycraft_bridge.light_occluded(origin, floor)
    receivers.floor.sunTransmission = garrycraft_bridge.light_transmission(floor + Vector(0,0,1),
        floor + Vector(0,0,1) + util.GetSunInfo().direction:GetNormalized() * 2048, GC.GridHeight)
    file.Write(prefix .. ".png", render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
    file.Write(prefix .. ".json", util.TableToJSON({pixels = pixels, width = ScrW(), height = ScrH(),
        view = tostring(origin), angles = tostring(angles), sun = GC.SunReport(), lights = GC.LightReport(),
        blocks = GC.BlockRenderReport(), exposure = GC.LightingExposure(origin), receivers = receivers,
        transport = GC.VoxelLight(origin), tone = tostring(render.GetToneMappingScaleLinear()), session = GC.State.session}, true))
end)
