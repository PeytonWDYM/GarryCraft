-- Passive observer for real mesh updates. Root drives Minecraft animation and block edits separately.
local GC = GarryCraft
local running
local hookName = "GarryCraftSourceModelRebindObserver"
local function key(kind, batch)
    return kind .. ":" .. batch.texture .. ":" .. batch.tintId .. ":" .. tostring(batch.unlit)
end
local function bindings()
    local expected, actual, slots = {}, {}, {}
    for _, group in ipairs({{kind="world", batches=GC.BlockShadowMeshes()}, {kind="avatar", batches=GC.AvatarMeshes()}}) do
        for _, batch in ipairs(group.batches) do
            if not batch.translucent and GC.RenderTexture(batch.texture) then
                local name = key(group.kind, batch)
                expected[name] = (expected[name] or 0) + 1
                local entry = batch.sourceModel
                local entity = entry and entry.entity
                local valid = IsValid(entity) and entry.batch == batch and entity.GarryCraftSourceModel == entry
                local renderMesh = valid and entity:GetRenderMesh()
                valid = valid and renderMesh.Mesh == batch.mesh and renderMesh.Material == GC.RenderMaterial(batch)
                if valid then actual[name] = (actual[name] or 0) + 1 end
                slots[#slots+1] = {kind=group.kind, texture=batch.texture, tint=batch.tintId, unlit=batch.unlit,
                    key=name, mesh=tostring(batch.mesh), entry=entry and tostring(entry) or "missing",
                    entity=IsValid(entity) and entity:EntIndex() or -1, bound=valid,
                    material=renderMesh and renderMesh.Material:GetName() or "missing"}
            end
        end
    end
    local entities = {}
    for _, entity in ipairs(ents.GetAll()) do
        if entity:GetClass() == "garrycraft_source_model" then
        local entry = entity.GarryCraftSourceModel
        entities[#entities+1] = {index=entity:EntIndex(), retiring=entry == nil,
            entry=entry and tostring(entry) or "retired", kind=entry and entry.kind or "retired",
            texture=entry and entry.batch.texture or -1, mesh=entry and tostring(entry.batch.mesh) or "retired"}
        end
    end
    return {expected=expected, actual=actual, slots=slots, entities=entities}
end
local function finish(reason)
    local run = running
    if not run then return end
    running = nil
    hook.Remove("PostRender", hookName)
    hook.Remove("ShutDown", hookName)
    hook.Add("CalcView", "GarryCraftCamera", run.camera)
    local final = GC.SourceModelReport()
    local native = garrycraft_bridge.shadow_stats()
    run.result.finished = reason
    run.result.duration = RealTime()-run.started
    run.result.final = {models=final,native=native}
    run.result.deltas = {created=final.created-run.result.initial.models.created,
        rebound=final.rebound-run.result.initial.models.rebound,
        castDraws=native.castDraws-run.result.initial.native.castDraws,
        modelDraws=native.modelDraws-run.result.initial.native.modelDraws}
    local baseline = run.result.initial.native
    run.result.checks = {completed=reason == "completed", frames=#run.result.frames > 1,
        matchingSlots=#run.result.missing == 0, invalidMeshes=native.invalidMeshes == baseline.invalidMeshes,
        wrongThread=native.wrongThread == baseline.wrongThread, staleEntities=native.staleEntities == baseline.staleEntities}
    file.Write(run.result.artifact, util.TableToJSON(run.result))
    if reason == "completed" then
        for check, passed in pairs(run.result.checks) do assert(passed, "Source model rebind observer failed " .. check .. "; read " .. run.result.artifact) end
    end
end
GC.SourceModelRebindTest = {}
function GC.SourceModelRebindTest.Begin(position, angles, seconds)
    assert(not running, "Wait for the existing rebind observation to finish")
    assert(game.SinglePlayer() and GC.State and GC.State.linked, "Use an owned linked single-player lab")
    position, angles, seconds = position or GC.ToSource(37.5,6.62,.5), angles or Angle(12.060,-174.509,0), seconds or 12
    local camera = hook.GetTable().CalcView.GarryCraftCamera
    assert(camera, "The linked lab must own its GarryCraftCamera hook")
    local started = RealTime()
    local id = tostring(math.floor(started*1000))
    local prefix = "garrycraft-lighting/source-model-rebind-" .. id
    file.CreateDir("garrycraft-lighting")
    running = {camera=camera, started=started, seconds=seconds, nextScreenshot=0,
        result={session=GC.State.session, artifact=prefix .. ".json", frames={}, missing={},
            initial={models=GC.SourceModelReport(),native=garrycraft_bridge.shadow_stats()},
            camera={origin=tostring(position),angles=tostring(angles)},
            pixelEncoding="base64-u8 row-major luminance", columns=96,rows=54}}
    hook.Add("CalcView", "GarryCraftCamera", function(...)
        -- Retain real camera bookkeeping and avatar interpolation while locking only this test viewport.
        local original = camera(...)
        GC.ViewOrigin, GC.ViewAngles = position, angles
        return {origin=position,angles=angles,fov=original.fov,drawviewer=original.drawviewer}
    end)
    hook.Add("ShutDown", hookName, function() finish("shutdown") end)
    hook.Add("PostRender", hookName, function()
        local run = running
        if not GC.State or not GC.State.linked then finish("disconnected") return end
        local work = SysTime()
        local elapsed = RealTime()-run.started
        local current = bindings()
        if elapsed >= 1 and run.previous then
            for name, count in pairs(current.expected) do
                local previous = run.previous.expected[name] or 0
                local required = math.min(previous,count)
                if required > (current.actual[name] or 0) then
                    run.result.missing[#run.result.missing+1] = {frame=#run.result.frames+1,time=elapsed,
                        key=name,required=required,actual=current.actual[name] or 0}
                end
            end
        end
        render.CapturePixels()
        local bytes, total, minimum, maximum, changed = {},0,255,0,0
        for y=1,54 do for x=1,96 do
            local r,g,b = render.ReadPixel(math.floor(ScrW()*x/97),math.floor(ScrH()*y/55))
            local value = math.Clamp(math.floor(.2126*r+.7152*g+.0722*b+.5),0,255)
            local index = #bytes+1
            bytes[index] = string.char(value)
            total,minimum,maximum = total+value,math.min(minimum,value),math.max(maximum,value)
            if run.pixels and math.abs(value-string.byte(run.pixels,index)) > 10 then changed=changed+1 end
        end end
        local pixels = table.concat(bytes)
        local frame = {time=elapsed, bindings=current, models=GC.SourceModelReport(),
            native=garrycraft_bridge.shadow_stats(),world=GC.BlockRenderReport(),avatar=GC.AvatarReport(),
            state={tick=GC.State.tick,camera=GC.State.camera,renderInstance=GC.State.renderInstance,
                teleportAck=GC.State.teleportAck,alive=LocalPlayer():Alive()},
            origin=tostring(GC.ViewOrigin),angles=tostring(GC.ViewAngles),
            pixels=util.Base64Encode(pixels),width=ScrW(),height=ScrH(),
            luminance={minimum=minimum,maximum=maximum,mean=total/5184,changed=changed}}
        if elapsed >= run.nextScreenshot then
            run.nextScreenshot = elapsed+2
            frame.screenshot = prefix .. "-" .. tostring(math.floor(elapsed*1000)) .. ".png"
            file.Write(frame.screenshot,render.Capture({format="png",x=0,y=0,w=ScrW(),h=ScrH(),alpha=false}))
        end
        frame.observerMilliseconds = (SysTime()-work)*1000
        run.result.frames[#run.result.frames+1] = frame
        run.previous,run.pixels = current,pixels
        if elapsed >= run.seconds then finish("completed") end
    end)
    return running.result.artifact
end
