-- Failures: native lamps cannot shade Minecraft meshes, fluid updates stall,
-- native props inherit stale draw state, or mesh shadows lose their silhouettes.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
local id = "GarryCraftSourceRenderingTest"
local camera = hook.GetTable().CalcView.GarryCraftCamera
local lampOn = false
local frameTimes, previousFrame = {}, nil
local lampKey = tonumber(util.CRC(id))
local view, target = GC.ToSource(38, 6, 9), GC.ToSource(38, 3, 0)
local lampPosition = GC.ToSource(38, 4.5, 3)
local prop = ClientsideModel("models/hunter/blocks/cube025x025x025.mdl")
prop:SetPos(GC.ToSource(40, 3.5, .5))
prop:SetMaterial("models/debug/debugwhite")
hook.Add("CalcView", "GarryCraftCamera", function()
    GC.ViewOrigin, GC.ViewAngles = view, (target - view):Angle()
    return {origin = view, angles = GC.ViewAngles, fov = 75}
end)
hook.Add("PreRender", id, function()
    local now = SysTime()
    if previousFrame then frameTimes[#frameTimes + 1] = (now - previousFrame) * 1000 end
    previousFrame = now
    local lamp = assert(DynamicLight(lampKey), "The fixture needs one free Source dynamic light")
    lamp.pos, lamp.size, lamp.brightness = lampPosition, 256, 3
    lamp.r, lamp.g, lamp.b = lampOn and 255 or 0, 0, 0
    lamp.decay, lamp.style, lamp.noworld, lamp.nomodel = 0, 0, false, false
    lamp.dietime = CurTime() + .2
end)
GC.SourceRenderingTest = {}
function GC.SourceRenderingTest.Lamp(enabled) lampOn = enabled end
function GC.SourceRenderingTest.WaterLamp()
    lampPosition = GC.ToSource(42.5, 5, 2.5)
    lampOn = true
end
function GC.SourceRenderingTest.Capture(label)
    hook.Add("PostRender", id, function()
        hook.Remove("PostRender", id)
        render.CapturePixels()
        local pixels = {}
        for name, point in pairs({block = GC.ToSource(37.5, 3.5, 1.01), prop = prop:GetPos(),
            water = GC.ToSource(42.5, 3.8, 2.5), floor = GC.ToSource(38.5, 3.01, 3.5)}) do
            local screen = point:ToScreen()
            local pixel = {screen = {screen.x, screen.y}, visible = screen.visible}
            if screen.visible and screen.x >= 1 and screen.x < ScrW()-1 and screen.y >= 1 and screen.y < ScrH()-1 then
                local r, g, b = render.ReadPixel(math.floor(screen.x), math.floor(screen.y))
                pixel.rgb = {r, g, b}
            end
            pixels[name] = pixel
        end
        local _, transparent = GC.BlockMeshes()
        local water = {}
        for _, batch in ipairs(transparent) do
            if batch.center:Distance(GC.ToSource(42.5, 3.5, 2.5)) < 160 then
                water[#water + 1] = {minimum = {batch.minimum:Unpack()}, maximum = {batch.maximum:Unpack()},
                    vertices = batch.vertices, geometry = batch.geometry, tint = {batch.tint:Unpack()}}
            end
        end
        local row = {pixels = pixels, water = water, frameTimes = frameTimes, blocks = GC.BlockRenderReport(),
            models = GC.SourceModelReport(), native = garrycraft_bridge.shadow_stats(), lamp = lampOn}
        frameTimes = {}
        file.CreateDir("garrycraft-source-rendering")
        file.Write("garrycraft-source-rendering/" .. label .. ".png", render.Capture({
            format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        file.Write("garrycraft-source-rendering/" .. label .. ".json", util.TableToJSON(row, true))
    end)
end
function GC.SourceRenderingTest.Stop()
    hook.Remove("PreRender", id)
    hook.Remove("PostRender", id)
    hook.Add("CalcView", "GarryCraftCamera", camera)
    local lamp = DynamicLight(lampKey)
    if lamp then lamp.r, lamp.g, lamp.b, lamp.dietime = 0, 0, 0, CurTime()-1 end
    prop:Remove()
end
