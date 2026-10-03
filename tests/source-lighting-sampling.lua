-- Run after the owned concave dirt/totem fixture arrives. Save raw Source samples and the actual cached ambient cube.
local GC = GarryCraft
local normals = {Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0), Vector(0,0,1), Vector(0,0,-1)}
assert(game.SinglePlayer() and GC.State and GC.State.linked, "Use an owned linked single-player lab")
local rows, started = {}, RealTime()
local function sample(name, position)
    local cache, raw = {colors = {}}, {}
    GC.PrepareLighting(position, cache)
    for index, normal in ipairs(normals) do
        local value = render.ComputeLighting(position, normal) - render.ComputeDynamicLighting(position, normal)
        raw[index] = {value.x, value.y, value.z}
    end
    local colors = {}
    for index, color in ipairs(cache.colors) do colors[index] = {color.x, color.y, color.z} end
    rows[#rows+1] = {name = name, position = {position.x, position.y, position.z}, raw = raw, actual = colors,
        exposure = garrycraft_bridge.light_exposure(position), solid = bit.band(util.PointContents(position), CONTENTS_SOLID) ~= 0}
    GC.RestoreLighting()
end
hook.Add("PostDrawTranslucentRenderables", "GarryCraftSourceLightingSampling", function(depth, skybox)
    if depth or skybox or #rows > 0 then return end
    sample("hands", GC.ViewOrigin)
    for index, batch in ipairs(GC.BlockShadowMeshes()) do
        local position = batch.center + (EyePos() - batch.center):GetNormalized() * .5
        if position:DistToSqr(EyePos()) < 256*256 then sample("block-" .. index, position) end
    end
end)
hook.Add("PostRender", "GarryCraftSourceLightingSampling", function()
    if #rows == 0 or RealTime()-started < .5 then return end
    local zeros = 0
    for _, row in ipairs(rows) do for index, value in ipairs(row.raw) do
        local actual = row.actual[index]
        if value[1]+value[2]+value[3] > .01 and actual[1]+actual[2]+actual[3] == 0 then zeros = zeros+1 end
    end end
    local prefix = "garrycraft-source-lighting-" .. (GC.SourceLightingTestLabel or "sample")
    file.Write(prefix .. ".png", render.Capture({format="png", x=0, y=0, w=ScrW(), h=ScrH(), alpha=false}))
    file.Write(prefix .. ".json", util.TableToJSON({rows=rows, positiveSourceDirectionsErased=zeros,
        session=GC.State.session, origin=tostring(GC.ViewOrigin), angles=tostring(GC.ViewAngles)}, true))
    hook.Remove("PostRender", "GarryCraftSourceLightingSampling")
    hook.Remove("PostDrawTranslucentRenderables", "GarryCraftSourceLightingSampling")
end)
