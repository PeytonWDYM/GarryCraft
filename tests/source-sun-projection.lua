-- Perspective sunlight probe for the real Minecraft fixture described in source-sun-projection.md.
local GC = GarryCraft
local running
local hookName = "GarryCraftSourceSunProjectionProbe"
local phases = {"none", "unshadowed", "shadowed", "restored"}
local function restore()
    local run = running
    if not run then return end
    if run.projector then run.projector:Remove() run.projector = nil end
    for entity, method in pairs(run.methods) do if IsValid(entity) then entity.RenderOverride = method.previous end end
    hook.Remove("Think", hookName)
    hook.Remove("PostRender", hookName)
    hook.Remove("PreDrawOpaqueRenderables", hookName)
    hook.Remove("ShutDown", hookName)
    hook.Add("CalcView", "GarryCraftCamera", run.camera)
end
local function region(x, y)
    if x >= .15 and x <= .85 and y >= .15 and y <= .6 then return "world" end
    if x <= .35 and y >= .6 and y <= .92 then return "leftHand" end
    if x >= .65 and y >= .6 and y <= .92 then return "rightHand" end
end
local function compare(a, b)
    local result = {}
    for _, name in ipairs({"world", "leftHand", "rightHand"}) do result[name] = {count=0,darkened=0,drop=0} end
    for y=1,54 do for x=1,96 do
        local name = region(x/97,y/55)
        if name then
            local index = (y-1)*96+x
            local drop = a.pixels[index]-b.pixels[index]
            local value = result[name]
            value.count, value.drop = value.count+1, value.drop+drop
            if drop > 5 then value.darkened = value.darkened+1 end
        end
    end end
    for _, value in pairs(result) do value.drop = value.drop/value.count end
    return result
end
local function finish(reason)
    local run = running
    restore()
    running = nil
    run.result.finished = reason
    run.result.nativeAfter = garrycraft_bridge.shadow_stats()
    local samples = run.result.samples
    if samples.shadowed then
        run.result.shadowDifference = compare(samples.unshadowed, samples.shadowed)
        run.result.addedLight = compare(samples.unshadowed, samples.none)
        run.result.samePose = true
        for _, sample in pairs(samples) do
            if sample.origin ~= samples.none.origin or sample.angles ~= samples.none.angles
                    or sample.width ~= samples.none.width or sample.height ~= samples.none.height then run.result.samePose = false end
        end
    end
    file.Write(run.result.artifact, util.TableToJSON(run.result))
end
GC.SourceSunProjectionTest = {}
function GC.SourceSunProjectionTest.Begin(label, options)
    assert(not running, "Wait for the existing sunlight probe to finish")
    assert(game.SinglePlayer() and GC.State and GC.State.linked, "Use an owned linked single-player lab")
    assert(GC.State.camera == 0, "Use first person to test the hidden avatar depth caster")
    local sun = util.GetSunInfo()
    assert(sun and sun.sunColor, "This probe needs Source sun direction and sunColor")
    options = options or {}
    local view = options.view or GC.ToSource(37.5,6.62,.5)
    local angles = options.angles or Angle(12.060,-174.509,0)
    local target = options.target or GC.ToSource(37.5,5.5,.5)
    local distance, brightness = options.distance or 768, options.brightness or .75
    local fov = options.fov or 45
    assert(options.attenuation == nil or options.attenuation == "constant", "Use the default or constant attenuation profile")
    local direction = sun.direction:GetNormalized()
    assert(direction.z > .05, "Use a Source sun above the room")
    local position = target+direction*distance
    local camera = hook.GetTable().CalcView.GarryCraftCamera
    assert(camera, "The linked lab must own its GarryCraftCamera hook")
    local name = string.gsub(label or "room", "[^%w%-]", "-")
    local prefix = "garrycraft-lighting/source-sun-" .. name .. "-" .. math.floor(RealTime()*1000)
    file.CreateDir("garrycraft-lighting")
    local projector = ProjectedTexture()
    projector:SetTexture("color/white")
    projector:SetPos(position)
    projector:SetAngles((-direction):Angle())
    projector:SetFOV(fov)
    projector:SetNearZ(16)
    projector:SetFarZ(distance+512)
    projector:SetColor(sun.sunColor)
    projector:SetBrightness(0)
    projector:SetEnableShadows(false)
    projector:SetShadowFilter(1)
    if options.attenuation == "constant" then
        projector:SetConstantAttenuation(1)
        projector:SetLinearAttenuation(0)
        projector:SetQuadraticAttenuation(0)
    end
    projector:Update()
    local brush = util.TraceLine({start=position,endpos=target,mask=MASK_SOLID_BRUSHONLY})
    running = {projector=projector, camera=camera, methods={}, index=1, ready=RealTime()+(options.settle or 1.25),
        settle=options.settle or 1.25, calls={}, result={label=name,artifact=prefix .. ".json",session=GC.State.session,
            sourceSun={direction=tostring(direction),color={sun.sunColor.r,sun.sunColor.g,sun.sunColor.b},obstruction=sun.obstruction},
            projector={position=tostring(position),target=tostring(target),distance=distance,brightness=brightness,
                fov=fov,nearZ=16,farZ=distance+512,perspective=true,texture="color/white",
                attenuation={profile=options.attenuation or "default",constant=projector:GetConstantAttenuation(),
                    linear=projector:GetLinearAttenuation(),quadratic=projector:GetQuadraticAttenuation()}},
            nativeBrush={startSolid=brush.StartSolid,hit=brush.Hit,fraction=brush.Fraction,position=tostring(brush.HitPos)},
            nativeBefore=garrycraft_bridge.shadow_stats(),samples={}}}
    hook.Add("CalcView", "GarryCraftCamera", function(...)
        local original = camera(...)
        GC.ViewOrigin, GC.ViewAngles = view, angles
        return {origin=view,angles=angles,fov=original.fov,drawviewer=false}
    end)
    hook.Add("Think", hookName, function()
        local run = running
        for _, entity in ipairs(ents.GetAll()) do
            if entity.GarryCraftSourceModel and not run.methods[entity] then
                local method = entity.RenderOverride or entity.Draw
                run.methods[entity] = {previous=rawget(entity:GetTable(),"RenderOverride")}
                -- RenderOverride is the public engine callback. DrawModel is a native method, not an instance callback.
                entity.RenderOverride = function(self, flags)
                    local entry = self.GarryCraftSourceModel
                    local phase = phases[run.index]
                    local counts = run.calls[phase] or {worldDepth=0,avatarDepth=0,worldColor=0,avatarColor=0,tallWorldDepth=0,
                        worldDepthCallbacks=0,avatarDepthCallbacks=0,worldColorCallbacks=0,avatarColorCallbacks=0,flags={}}
                    run.calls[phase] = counts
                    local depth = bit.band(flags,STUDIO_SHADOWDEPTHTEXTURE+STUDIO_SSAODEPTHTEXTURE) ~= 0
                    if entry and (entry.kind == "world" or entry.kind == "avatar") then
                        local field = entry.kind .. (depth and "Depth" or "Color")
                        counts[field .. "Callbacks"] = counts[field .. "Callbacks"]+1
                        counts.flags[tostring(flags)] = (counts.flags[tostring(flags)] or 0)+1
                        -- The production counter advances only after its visibility guards, immediately before DrawModel.
                        local before = GC.SourceModelReport().colorDraws[entry.kind]
                        method(self,flags)
                        local drawn = GC.SourceModelReport().colorDraws[entry.kind]-before
                        counts[field] = counts[field]+drawn
                        if depth and entry.kind == "world" and entry.batch.maximum.z-entry.batch.minimum.z >= 63 then
                            counts.tallWorldDepth = counts.tallWorldDepth+drawn
                        end
                        return
                    end
                    return method(self,flags)
                end
            end
        end
    end)
    hook.Add("PreDrawOpaqueRenderables", hookName, function(depth,skybox)
        if not depth and not skybox and running.projector then running.projector:Update() end
    end)
    hook.Add("ShutDown", hookName, function() finish("shutdown") end)
    hook.Add("PostRender", hookName, function()
        local run = running
        if not GC.State or not GC.State.linked then finish("disconnected") return end
        if RealTime() < run.ready then return end
        local phase = phases[run.index]
        render.CapturePixels()
        local pixels = {}
        for y=1,54 do for x=1,96 do
            local r,g,b = render.ReadPixel(math.floor(ScrW()*x/97),math.floor(ScrH()*y/55))
            pixels[#pixels+1] = .2126*r+.7152*g+.0722*b
        end end
        local screenshot = prefix .. "-" .. phase .. ".png"
        file.Write(screenshot,render.Capture({format="png",x=0,y=0,w=ScrW(),h=ScrH(),alpha=false}))
        run.result.samples[phase] = {pixels=pixels,columns=96,rows=54,width=ScrW(),height=ScrH(),screenshot=screenshot,
            origin=tostring(GC.ViewOrigin),angles=tostring(GC.ViewAngles),camera=GC.State.camera,
            drawCalls=run.calls[phase] or {},models=GC.SourceModelReport(),native=garrycraft_bridge.shadow_stats(),
            world=GC.BlockRenderReport(),avatar=GC.AvatarReport()}
        run.index = run.index+1
        if run.index > #phases then finish("completed") return end
        if phases[run.index] == "restored" then
            run.projector:Remove() run.projector = nil
        else
            run.projector:SetBrightness(brightness)
            run.projector:SetEnableShadows(phases[run.index] == "shadowed")
            run.projector:Update()
        end
        run.ready = RealTime()+run.settle
    end)
    return running.result.artifact
end
