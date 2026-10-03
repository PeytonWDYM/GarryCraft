-- Tests local-light overrides on the actual opaque Minecraft Source proxies before changing their renderer.
local GC = GarryCraft
assert(game.SinglePlayer() and GC.State and GC.State.linked, "Use an owned linked single-player lab")
assert(GC.LightReport().exported == 0, "Use the concave fixture without Minecraft emitters")
local entities, previous = {}, {}
for _, entity in ipairs(ents.FindByClass("garrycraft_source_model")) do
    local entry = entity.GarryCraftSourceModel
    if entry and entry.kind == "world" then
        entities[#entities + 1] = entity
        previous[entity] = entity.RenderOverride
    end
end
assert(#entities > 0, "Wait for opaque Minecraft Source proxies")
local normals = {Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0), Vector(0,0,1), Vector(0,0,-1)}
local view = GC.ToSource(37.5,6.62,.5)
local angles = Angle(12.060,-174.509,0)
local camera = hook.GetTable().CalcView.GarryCraftCamera
assert(camera, "The linked lab must own its normal GarryCraftCamera hook")
hook.Add("CalcView", "GarryCraftCamera", function()
    GC.ViewOrigin, GC.ViewAngles = view, angles
    return {origin=view,angles=angles,fov=70,drawviewer=false}
end)
local position = view + angles:Forward() * 32 + Vector(0,0,16)
local point = {type=MATERIAL_LIGHT_POINT, pos=position, color=Vector(1,0,0),
    fiftyPercentDistance=128, zeroPercentDistance=256}
local key = tonumber(util.CRC("garrycraft/test/proxy-source-light"))
local stage, ready, rows = 1, RealTime()+.75, {}
local names = {"native", "localAuto", "localManual"}
local function cleanup()
    hook.Add("CalcView", "GarryCraftCamera", camera)
    for _, entity in ipairs(entities) do if IsValid(entity) then entity.RenderOverride = previous[entity] end end
    local lamp = DynamicLight(key)
    if lamp then lamp.r,lamp.g,lamp.b,lamp.dietime = 0,0,0,CurTime()-1 end
    hook.Remove("PreRender", "GarryCraftSourceModelLightProbe")
    hook.Remove("PostRender", "GarryCraftSourceModelLightProbe")
    hook.Remove("ShutDown", "GarryCraftSourceModelLightProbe")
end
for _, entity in ipairs(entities) do
    entity.RenderOverride = function(self, flags)
        if stage == 1 then self:DrawModel(flags) return end
        if stage == 3 then
            -- Sample real Source light; the red local torch has no DynamicLight allocation to double count.
            for axis, normal in ipairs(normals) do
                local color = render.ComputeLighting(self:GetPos(), normal)
                render.SetModelLighting(axis-1, color.x,color.y,color.z)
            end
            render.SuppressEngineLighting(true)
        end
        render.SetLocalModelLights({point})
        self:DrawModel(flags)
        if stage == 3 then render.SuppressEngineLighting(false) end
        GC.RestoreLighting()
    end
end
hook.Add("ShutDown", "GarryCraftSourceModelLightProbe", cleanup)
hook.Add("PreRender", "GarryCraftSourceModelLightProbe", function()
    local lamp = DynamicLight(key)
    assert(lamp, "Owned Source lamp needs one free dynamic-light slot")
    lamp.pos,lamp.size,lamp.brightness = position,256,2
    lamp.r,lamp.g,lamp.b = 64,128,255
    lamp.decay,lamp.style,lamp.noworld,lamp.nomodel = 0,0,false,false
    lamp.dietime = CurTime()+.2
end)
hook.Add("PostRender", "GarryCraftSourceModelLightProbe", function()
    if RealTime() < ready then return end
    local name = names[stage]
    render.CapturePixels()
    local grid = {columns=64,rows=36,width=ScrW(),height=ScrH(),pixels={}}
    for y=1,36 do for x=1,64 do
        local r,g,b = render.ReadPixel(math.floor(ScrW()*(.15+.7*x/65)), math.floor(ScrH()*(.15+.6*y/37)))
        grid.pixels[#grid.pixels+1] = {r,g,b}
    end end
    local screenshot = "garrycraft-lighting/source-model-local-" .. name .. ".png"
    file.Write(screenshot, render.Capture({format="png",x=0,y=0,w=ScrW(),h=ScrH(),alpha=false}))
    rows[name] = {grid=grid,screenshot=screenshot,origin=tostring(GC.ViewOrigin),angles=tostring(GC.ViewAngles),
        shadows=GC.ShadowReport()}
    stage = stage+1
    if stage <= #names then ready=RealTime()+.75 return end
    cleanup()
    file.Write("garrycraft-source-model-local-lights.json", util.TableToJSON({rows=rows,session=GC.State.session},true))
end)
