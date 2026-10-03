local GC = GarryCraft
local particles = {}
local entities = {}
local vertices = 0
local particlesRevision, entitiesRevision
local itemModels, items = {}, {}
local terrainRequest, debrisPeak = nil, 0

function GC.ClearWorldScene()
    GC.DestroyRenderMeshes(particles)
    GC.DestroyRenderMeshes(entities)
    particles, entities = {}, {}
    vertices = 0
    particlesRevision, entitiesRevision = nil, nil
    for _, model in pairs(itemModels) do GC.DestroyRenderMeshes(model) end
    itemModels, items = {}, {}
end

function GC.AcceptWorldScene(scene, body)
    local used = {}
    for _, model in ipairs(scene.itemModels) do
        used[model.id] = true
        if not itemModels[model.id] then itemModels[model.id] = GC.BuildRenderMeshes(model.batches, false, false, body) end
    end
    for id, model in pairs(itemModels) do
        if not used[id] then GC.DestroyRenderMeshes(model) itemModels[id] = nil end
    end
    items = {}
    for _, item in ipairs(scene.items) do
        local transform = Matrix()
        for row = 1, 3 do for column = 1, 4 do transform:SetField(row, column, item.transform[(row - 1) * 4 + column]) end end
        transform:SetField(3, 4, transform:GetField(3, 4) + GC.GridHeight)
        items[#items + 1] = {model = item.model, transform = transform}
    end
    if particlesRevision ~= scene.particles.revision then
        GC.DestroyRenderMeshes(particles)
        particles = GC.BuildRenderMeshes(scene.particles.batches, false, true, body)
        particlesRevision = scene.particles.revision
        vertices = 0
        for _, batch in ipairs(scene.particles.batches) do vertices = vertices + batch.count end
    end
    if entitiesRevision ~= scene.entities.revision then
        GC.DestroyRenderMeshes(entities) entities = GC.BuildRenderMeshes(scene.entities.batches, false, true, body) entitiesRevision = scene.entities.revision
    end
end

hook.Add("PostDrawTranslucentRenderables", "GarryCraftWorldEffects", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or not GC.State.linked then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    GC.DrawRenderMeshes(entities, false)
    for _, item in ipairs(items) do
        cam.PushModelMatrix(item.transform)
        GC.DrawRenderMeshes(itemModels[item.model], false, item.transform:GetTranslation())
        cam.PopModelMatrix()
    end
    local drawn = GC.DrawRenderMeshes(particles, true)
    GC.RestoreLighting()
    if terrainRequest ~= GC.State.terrainTestRequest then terrainRequest = GC.State.terrainTestRequest debrisPeak = 0 end
    if GC.State.terrainTestPhase == "breaking" then debrisPeak = math.max(debrisPeak, drawn) end
end)

concommand.Add("garrycraft_world_report", function()
    local report = {particleVertices = vertices, entityBatches = #entities, particleBatches = #particles,
        itemModels = table.Count(itemModels), itemInstances = #items, terrainRequest = terrainRequest, debrisVerticesDrawn = debrisPeak}
    file.Write("garrycraft-world.json", util.TableToJSON(report))
    print("GarryCraft world: " .. util.TableToJSON(report))
end)

hook.Add("ShutDown", "GarryCraftWorldCleanup", GC.ClearWorldScene)
