local GC = GarryCraft
local particles = {}
local entities = {}
local vertices = 0
local particlesRevision, entitiesRevision
local itemModels, items = {}, {}
local terrainRequest, debrisPeak = nil, 0

local function clearItems()
    for _, item in ipairs(items) do
        for _, proxy in ipairs(item.proxies) do GC.RemoveSourceModel(proxy) end
    end
    items = {}
end

function GC.ClearWorldScene()
    clearItems()
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
        if not itemModels[model.id] then
            local batches = GC.BuildRenderMeshes(model.batches, false, false, body)
            batches.transparent = {}
            for _, batch in ipairs(batches) do if batch.translucent then batches.transparent[#batches.transparent + 1] = batch end end
            itemModels[model.id] = batches
        end
    end
    for id, model in pairs(itemModels) do
        if not used[id] then GC.DestroyRenderMeshes(model) itemModels[id] = nil end
    end
    local previousItems = items
    items = {}
    for _, item in ipairs(scene.items) do
        local transform = Matrix()
        for row = 1, 3 do for column = 1, 4 do transform:SetField(row, column, item.transform[(row - 1) * 4 + column]) end end
        transform:SetField(3, 4, transform:GetField(3, 4) + GC.GridHeight)
        local index = #items + 1
        local previous = previousItems[index]
        local proxies = {}
        if previous and previous.model == item.model then
            proxies = previous.proxies
            previousItems[index] = nil
            for _, proxy in ipairs(proxies) do GC.UpdateSourceModel(proxy, transform * proxy.batch.center, transform) end
        else
            for _, batch in ipairs(itemModels[item.model]) do
                if not batch.translucent then proxies[#proxies + 1] = GC.CreateSourceModel(batch, "item", transform * batch.center, transform) end
            end
        end
        items[index] = {model = item.model, transform = transform, proxies = proxies}
    end
    for _, previous in pairs(previousItems) do
        for _, proxy in ipairs(previous.proxies) do GC.RemoveSourceModel(proxy) end
    end
    if particlesRevision ~= scene.particles.revision then
        GC.DestroyRenderMeshes(particles)
        particles = GC.BuildRenderMeshes(scene.particles.batches, false, true, body)
        particlesRevision = scene.particles.revision
        vertices = 0
        for _, batch in ipairs(scene.particles.batches) do vertices = vertices + batch.count end
    end
    if entitiesRevision ~= scene.entities.revision then
        local previous = entities
        entities = GC.BuildRenderMeshes(scene.entities.batches, false, true, body, "world", previous)
        GC.DestroyRenderMeshes(previous)
        entitiesRevision = scene.entities.revision
    end
end

hook.Add("PostDrawTranslucentRenderables", "GarryCraftWorldEffects", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or not GC.State.linked then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    GC.DrawRenderMeshes(entities, false)
    for _, item in ipairs(items) do
        -- Opaque item instances use model proxies. Source also shades their sorted transparent batches.
        GC.DrawRenderMeshes(itemModels[item.model].transparent, false, item.transform:GetTranslation(), item.transform)
    end
    local drawn = GC.DrawRenderMeshes(particles, true)
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
