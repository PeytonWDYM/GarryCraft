-- Run in the owned linked lab with no Minecraft emitters; the probe owns exactly two temporary lights.
local GC = GarryCraft
assert(game.SinglePlayer() and GC.State and GC.State.linked, "Use an owned linked single-player lab")
assert(GC.LightReport().exported == 0, "Remove Minecraft emitters before this controlled lamp probe")
local origin = Vector(GC.ViewOrigin.x, GC.ViewOrigin.y, GC.ViewOrigin.z)
local angles = tostring(GC.ViewAngles)
local normals = {Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0), Vector(0,0,1), Vector(0,0,-1)}
local mcKey = tonumber(util.CRC("garrycraft/test/owned-minecraft-light"))
local nativeKey = tonumber(util.CRC("garrycraft/test/owned-source-light"))
local stages = {{name="baseline", mc=0, native=0}, {name="minecraft", mc=2, native=0},
    {name="native", mc=0, native=2}, {name="both", mc=2, native=2}}
local index, ready, rows = 1, RealTime() + .75, {}
local function light(key, position, brightness, r, g, b)
    local value = DynamicLight(key)
    assert(value, "Owned lamp probe needs two free Source dynamic-light slots")
    value.pos, value.size, value.brightness = position, 256, brightness
    value.r, value.g, value.b = brightness > 0 and r or 0, brightness > 0 and g or 0, brightness > 0 and b or 0
    value.decay, value.style, value.noworld, value.nomodel = 0, 0, false, false
    value.dietime = CurTime() + .2
    return value
end
local function cleanup()
    for _, key in ipairs({mcKey, nativeKey}) do
        local value = DynamicLight(key)
        if value then value.brightness, value.dietime = 0, CurTime() - 1 end
    end
    hook.Remove("PreRender", "GarryCraftSourceDynamicProbe")
    hook.Remove("PostRender", "GarryCraftSourceDynamicProbe")
    hook.Remove("ShutDown", "GarryCraftSourceDynamicProbe")
end
hook.Add("ShutDown", "GarryCraftSourceDynamicProbe", cleanup)
hook.Add("PreRender", "GarryCraftSourceDynamicProbe", function()
    local stage = stages[index]
    light(mcKey, origin + Vector(64,0,32), stage.mc, 255,200,120)
    light(nativeKey, origin + Vector(-64,0,32), stage.native, 96,160,255)
end)
local function read()
    local result = {}
    for axis, normal in ipairs(normals) do
        local full = render.ComputeLighting(origin, normal)
        local dynamic = render.ComputeDynamicLighting(origin, normal)
        result[axis] = {full={full.x,full.y,full.z}, dynamic={dynamic.x,dynamic.y,dynamic.z},
            legacy={full.x-dynamic.x,full.y-dynamic.y,full.z-dynamic.z}}
    end
    return result
end
local function sourceOnly(before, muted)
    local result = {}
    for axis, value in ipairs(before) do
        result[axis] = {}
        for channel = 1, 3 do
            result[axis][channel] = value.full[channel] - value.dynamic[channel] + muted[axis].dynamic[channel]
        end
    end
    return result
end
hook.Add("PostRender", "GarryCraftSourceDynamicProbe", function()
    if RealTime() < ready then return end
    local stage = stages[index]
    local normal = read()
    local owned = DynamicLight(mcKey)
    -- Brightness is an exponent: zero is still luminous. DynamicLight fields have no readable getters.
    owned.r, owned.g, owned.b = 0, 0, 0
    local colorSuspended = read()
    light(mcKey, origin + Vector(64,0,32), stage.mc, 255,200,120)
    owned = DynamicLight(mcKey)
    owned.size = 0
    local radiusSuspended = read()
    light(mcKey, origin + Vector(64,0,32), stage.mc, 255,200,120)
    local cache = {colors={}}
    GC.PrepareLighting(origin, cache)
    local actual = {}
    for axis, color in ipairs(cache.colors) do actual[axis] = {color.x,color.y,color.z} end
    GC.RestoreLighting()
    file.CreateDir("garrycraft-lighting")
    local screenshot = "garrycraft-lighting/source-dynamic-" .. stage.name .. ".png"
    file.Write(screenshot, render.Capture({format="png", x=0, y=0, w=ScrW(), h=ScrH(), alpha=false}))
    rows[stage.name] = {normal=normal, minecraftColorSuspended=colorSuspended,
        minecraftRadiusSuspended=radiusSuspended, sourceOnlyColor=sourceOnly(normal,colorSuspended),
        sourceOnlyRadius=sourceOnly(normal,radiusSuspended), restored=read(), actual=actual, screenshot=screenshot,
        origin=tostring(GC.ViewOrigin), angles=tostring(GC.ViewAngles), restoredBrightness=stage.mc}
    index = index + 1
    if index <= #stages then ready = RealTime() + .75 return end
    cleanup()
    file.Write("garrycraft-source-dynamic-lighting.json", util.TableToJSON({session=GC.State.session,
        sampleOrigin=tostring(origin), initialAngles=angles, rows=rows}, true))
end)
