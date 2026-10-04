local GC = GarryCraft
local models = {}
local revision
local nextReady = {}
local destructionTextures = {}
local crackDraws, lastCrackStage, lastCrackId, lastCrackTexture, lastCrackAt = 0, -1, 0, -1, 0

local function ready(batches)
    if #batches == 0 then return false end
    for _, batch in ipairs(batches) do if not GC.RenderTexture(batch.texture) then return false end end
    return true
end

local function bind(entity, batches)
    if #batches == 0 then return false end
    local minimum, maximum = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
    local shadows = {}
    for _, batch in ipairs(batches) do
        if not GC.RenderTexture(batch.texture) then return false end
        for axis = 1, 3 do
            minimum[axis] = math.min(minimum[axis], batch.minimum[axis])
            maximum[axis] = math.max(maximum[axis], batch.maximum[axis])
        end
        shadows[#shadows + 1] = {mesh = batch.mesh, material = GC.RenderMaterial(batch)}
    end
    entity.GarryCraftPhysicsBatches = batches
    entity.GarryCraftPhysicsBatch = nil
    entity:SetRenderBounds(minimum, maximum)
    garrycraft_bridge.shadow_update(entity, shadows)
    entity:DrawShadow(true)
    entity:CreateShadow()
    entity:MarkShadowAsDirty()
    return true
end

local function unregister(entity)
    garrycraft_bridge.shadow_remove(entity)
    entity:DestroyShadow()
    entity.GarryCraftPhysicsBatches = nil
    entity.GarryCraftPhysicsBatch = nil
end

function GC.ClearPhysicsBlockModels()
    for _, entity in ipairs(ents.FindByClass("gc_physics_block")) do unregister(entity) end
    for _, batches in pairs(models) do GC.DestroyRenderMeshes(batches) end
    models = {}
    revision = nil
    nextReady = {}
    destructionTextures = {}
    crackDraws, lastCrackStage, lastCrackId, lastCrackTexture, lastCrackAt = 0, -1, 0, -1, 0
end

function GC.SetPhysicsBlockModels(payload, body)
    if payload.revision == revision then return end
    local replacement = {}
    for _, model in ipairs(payload.models) do
        replacement[model.id] = GC.BuildRenderMeshes(model.batches, false, false, body)
    end
    local previous = models
    models = replacement
    revision = payload.revision
    destructionTextures = payload.destructionTextures
    nextReady = {}
    -- Existing server bodies keep their physics and Source shadow handles across render generations.
    for _, entity in ipairs(ents.FindByClass("gc_physics_block")) do
        local batches = models[entity:GetBlockId()]
        if not batches or not bind(entity, batches) then unregister(entity) end
    end
    for _, batches in pairs(previous) do GC.DestroyRenderMeshes(batches) end
end

function GC.DrawPhysicsBlock(entity, flags, translucent)
    local batches = entity.GarryCraftPhysicsBatches
    if not batches or GC.VideoReset or not GC.State or not GC.State.linked then return end
    for _, batch in ipairs(batches) do
        if batch.translucent == translucent and GC.RenderTexture(batch.texture) then
            entity.GarryCraftPhysicsBatch = batch
            entity:DrawModel(flags)
        end
    end
    entity.GarryCraftPhysicsBatch = nil
end

-- Capture this report while holding attack to verify stage delivery, texture readiness, and actual mesh draws.
function GC.PhysicsBlockRenderReport()
    local currentModels, textures = {}, {}
    for id, batches in pairs(models) do
        local vertices = 0
        for _, batch in ipairs(batches) do vertices = vertices + batch.vertices end
        currentModels[#currentModels + 1] = {id = id, batches = #batches, vertices = vertices, ready = ready(batches)}
    end
    for index, texture in ipairs(destructionTextures) do
        textures[#textures + 1] = {stage = index - 1, texture = texture, ready = GC.RenderTexture(texture) ~= nil}
    end
    return {revision = revision, models = currentModels, destructionTextures = textures,
        mining = GC.State and GC.State.physicsBlockMining,
        crackDraws = crackDraws, lastStage = lastCrackStage, lastId = lastCrackId,
        lastTexture = lastCrackTexture, lastDrawAt = lastCrackAt}
end

hook.Add("Think", "GarryCraftPhysicsBlockModels", function()
    local attached = {}
    for _, entity in ipairs(ents.FindByClass("gc_physics_block")) do
        local batches = GC.State and entity:GetBlockSession() == GC.State.session and models[entity:GetBlockId()]
        if batches ~= entity.GarryCraftPhysicsBatches then
            if batches then
                bind(entity, batches)
            elseif entity.GarryCraftPhysicsBatches then unregister(entity) end
        end
        if batches and entity.GarryCraftPhysicsBatches == batches then attached[entity:GetBlockId()] = true end
    end
    if GC.State and GC.State.linked and not GC.VideoReset then
        for id, batches in pairs(models) do
            if not attached[id] and ready(batches) and RealTime() >= (nextReady[id] or 0) then
                net.Start("garrycraft_physics_block_ready")
                net.WriteUInt(id, 32)
                net.WriteString(GC.State.session)
                net.WriteString(GC.State.renderInstance)
                net.SendToServer()
                nextReady[id] = RealTime() + .25
            end
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "GarryCraftDetachedBlockCracks", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or not GC.State.linked then return end
    local progress = GC.State.physicsBlockMining
    if not progress or progress.stage < 0 then return end
    local texture = destructionTextures[progress.stage + 1]
    local material = texture and GC.RenderTexture(texture)
    if not material then return end
    for _, entity in ipairs(ents.FindByClass("gc_physics_block")) do
        if entity:GetBlockId() == progress.id and entity:GetBlockSession() == GC.State.session and entity.GarryCraftPhysicsBatches then
            local transform = Matrix()
            transform:SetTranslation(entity:GetPos())
            transform:SetAngles(entity:GetAngles())
            transform:SetScale(Vector(1.002, 1.002, 1.002))
            cam.PushModelMatrix(transform)
            render.SetMaterial(material.unlit)
            for _, batch in ipairs(entity.GarryCraftPhysicsBatches) do
                batch.mesh:Draw()
                crackDraws = crackDraws + 1
            end
            cam.PopModelMatrix()
            lastCrackStage, lastCrackId, lastCrackTexture, lastCrackAt = progress.stage, progress.id, texture, RealTime()
        end
    end
end)
