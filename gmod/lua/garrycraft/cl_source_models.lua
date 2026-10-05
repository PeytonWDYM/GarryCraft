local GC = GarryCraft
local entries = {}
local removals = {}
local class = "garrycraft_source_model"
local backing = "models/hunter/blocks/cube025x025x025.mdl"
local draws = {avatar = 0, world = 0, item = 0}
local created, rebound = 0, 0
local manual
local manualDraws = 0
local shadowWarning

-- One hidden model submits sorted fluids, hands, and arms through Source's normal studio lighting.
scripted_ents.Register({Type = "anim", Base = "base_anim", RenderGroup = RENDERGROUP_OTHER,
    Initialize = function(self)
        self:SetModel(backing)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)
    end,
    GetRenderMesh = function(self)
        local batch = self.GarryCraftBatch
        if not batch then return end
        return {Mesh = batch.mesh, Material = GC.RenderMaterial(batch), Matrix = self.GarryCraftMatrix}
    end}, "garrycraft_manual_model")

function GC.DrawSourceMesh(batch, position, transform)
    if not IsValid(manual) then return end
    local matrix = Matrix()
    if transform then matrix:Set(transform) end
    position = position or batch.surfaceOrigin
    matrix:SetTranslation(matrix:GetTranslation() - position)
    manual:SetPos(position)
    manual.GarryCraftBatch, manual.GarryCraftMatrix = batch, matrix
    -- Source caches the first draw's pose. Refresh it for each position in the sorted pass.
    manual:SetupBones()
    manual:DrawModel()
    manual.GarryCraftBatch = nil
    manualDraws = manualDraws + 1
end

scripted_ents.Register({Type = "anim", Base = "base_anim", RenderGroup = RENDERGROUP_OPAQUE,
    Initialize = function(self)
        self:SetModel(backing)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
    end,
    GetRenderMesh = function(self)
        local entry = self.GarryCraftSourceModel
        if not entry then return end
        return {Mesh = entry.batch.mesh, Material = GC.RenderMaterial(entry.batch), Matrix = entry.matrix}
    end,
    Draw = function(self, flags)
        local entry = self.GarryCraftSourceModel
        if not entry then return end
        if GC.VideoReset or not GC.State or not GC.State.linked then return end
        local depth = bit.band(flags, STUDIO_SHADOWDEPTHTEXTURE + STUDIO_SSAODEPTHTEXTURE) ~= 0
        if entry.kind == "avatar" and ((GC.State.camera == 0 and not depth) or not LocalPlayer():Alive()
            or GC.State.teleportAck ~= LocalPlayer():GetNWInt("GarryCraftTeleport")) then return end
        draws[entry.kind] = draws[entry.kind] + 1
        self:DrawModel(flags)
    end,
    OnRemove = function(self)
        local entry = self.GarryCraftSourceModel
        if entry then
            garrycraft_bridge.shadow_remove(self)
            entry.entity = nil
        end
    end}, class)

local function register(entry)
    local entity = entry.entity
    local ready, failure = garrycraft_bridge.shadow_update(entity, {{mesh = entry.batch.mesh,
        material = GC.RenderMaterial(entry.batch), matrix = entry.matrix}})
    if entry.shadowReady ~= ready then
        entity:DrawShadow(ready)
        if ready then entity:CreateShadow() end
        entry.shadowReady = ready
    end
    if ready then
        entity:MarkShadowAsDirty()
    elseif not shadowWarning then
        shadowWarning = failure
        ErrorNoHalt("[GarryCraft] Custom mesh shadows are unavailable. Rendering and gameplay remain active. " .. failure .. "\n")
    end
    return ready
end

local function create(entry)
    local entity = ents.CreateClientside(class)
    entity.GarryCraftSourceModel = entry
    entry.entity = entity
    entity:SetPos(entry.position)
    entity:Spawn()
    entity:SetRenderBounds(entry.minimum, entry.maximum)
    entry.shadowReady = nil
    register(entry)
    created = created + 1
end

-- Meshes keep their exported coordinates. The entity owns the world position and lighting origin.
function GC.CreateSourceModel(batch, kind, position, transform)
    local entry = {batch = batch, kind = kind, position = position, matrix = Matrix()}
    entries[entry] = true
    batch.sourceModels = batch.sourceModels or {}
    batch.sourceModels[entry] = true
    GC.UpdateSourceModel(entry, position, transform)
    return entry
end

-- Transform the measured mesh bounds, including item rotation and scale, into entity-local bounds.
function GC.UpdateSourceModel(entry, position, transform)
    entry.position = position
    entry.matrix:Set(transform)
    entry.matrix:SetTranslation(transform:GetTranslation() - position)
    local minimum, maximum = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
    local batch = entry.batch
    for _, x in ipairs({batch.minimum.x, batch.maximum.x}) do
        for _, y in ipairs({batch.minimum.y, batch.maximum.y}) do
            for _, z in ipairs({batch.minimum.z, batch.maximum.z}) do
                local point = entry.matrix * Vector(x, y, z)
                for axis = 1, 3 do
                    minimum[axis] = math.min(minimum[axis], point[axis])
                    maximum[axis] = math.max(maximum[axis], point[axis])
                end
            end
        end
    end
    entry.minimum, entry.maximum = minimum, maximum
    if IsValid(entry.entity) then
        entry.entity:SetPos(position)
        entry.entity:SetRenderBounds(minimum, maximum)
        register(entry)
    end
end

local function retireEntity(entry)
    local entity = entry.entity
    if IsValid(entity) then
        -- Unregister before either the entity or its explicit IMesh can retire.
        entity:SetNoDraw(true)
        entity.GarryCraftSourceModel = nil
        garrycraft_bridge.shadow_remove(entity)
        entity:DestroyShadow()
        removals[entity] = true
    end
    entry.entity = nil
end

-- Source forbids entity removal during render hooks. Retired entities cannot draw while they wait.
local function removeEntities()
    for entity in pairs(removals) do
        if IsValid(entity) then entity:Remove() end
        removals[entity] = nil
    end
end

-- Rebind a replaced owner's opaque slots before its old meshes retire. Source keeps each entity and shadow handle.
function GC.SyncSourceModels(batches, previous, kind)
    local available = {}
    local retained = {}
    for _, batch in ipairs(batches) do retained[batch] = true end
    for _, batch in ipairs(previous) do
        if batch.sourceModel and not retained[batch] then available[#available + 1] = batch.sourceModel end
    end
    for _, batch in ipairs(batches) do
        if not batch.translucent and not batch.sourceModel then
            local match = 1
            for index, candidate in ipairs(available) do
                if candidate.batch.texture == batch.texture and candidate.batch.unlit == batch.unlit
                    and candidate.batch.tintId == batch.tintId then match = index break end
            end
            local entry
            if #available > 0 then entry = table.remove(available, match) end
            local position = kind == "avatar" and (entry and entry.position or GC.ToSource(GC.State.x, GC.State.y, GC.State.z))
                or batch.surfaceOrigin
            local transform = Matrix()
            if kind == "avatar" then transform:SetTranslation(position) end
            if entry then
                local old = entry.batch
                old.sourceModels[entry] = nil
                old.sourceModel = nil
                entry.batch = batch
                batch.sourceModels = {[entry] = true}
                batch.sourceModel = entry
                if IsValid(entry.entity) and not GC.RenderTexture(batch.texture) then retireEntity(entry) end
                GC.UpdateSourceModel(entry, position, transform)
                rebound = rebound + 1
            else
                batch.sourceModel = GC.CreateSourceModel(batch, kind, position, transform)
            end
        end
    end
end

function GC.RemoveSourceModel(entry)
    entries[entry] = nil
    entry.batch.sourceModels[entry] = nil
    if entry.batch.sourceModel == entry then entry.batch.sourceModel = nil end
    retireEntity(entry)
end

function GC.RemoveSourceMeshModels(batch)
    if not batch.sourceModels then return end
    for entry in pairs(batch.sourceModels) do GC.RemoveSourceModel(entry) end
end

function GC.ClearSourceModels()
    for entry in pairs(entries) do GC.RemoveSourceModel(entry) end
    garrycraft_bridge.shadow_clear()
end

function GC.SourceModelReport()
    local counts = {avatar = 0, world = 0, item = 0, pending = 0, retiring = table.Count(removals),
        created = created, rebound = rebound, colorDraws = table.Copy(draws), manualDraws = manualDraws,
        manualReady = IsValid(manual)}
    for entry in pairs(entries) do
        if IsValid(entry.entity) then counts[entry.kind] = counts[entry.kind] + 1 else counts.pending = counts.pending + 1 end
    end
    return counts
end

-- CalcView publishes the current interpolated feet before Source renders color and RTT shadows.
function GC.UpdateSourceAvatarPosition(position)
    for entry in pairs(entries) do
        if entry.kind == "avatar" then
            entry.position = position
            if IsValid(entry.entity) and entry.entity:GetPos() ~= position then
                entry.entity:SetPos(position)
                entry.entity:MarkShadowAsDirty()
            end
        end
    end
end

hook.Add("Think", "GarryCraftSourceModels", function()
    removeEntities()
    local player = LocalPlayer()
    if GC.VideoReset or not GC.State or not GC.State.linked or not IsValid(player) or not player:GetNWBool("GarryCraft") then
        -- A bridge stall retains mesh revisions. Keep their bindings so they can resume unchanged.
        for entry in pairs(entries) do if IsValid(entry.entity) then retireEntity(entry) end end
        removeEntities()
        if IsValid(manual) then manual:Remove() end
        manual = nil
        return
    end
    if not IsValid(manual) then
        manual = ents.CreateClientside("garrycraft_manual_model")
        manual:Spawn()
    end
    local avatarReady = player:Alive() and GC.State.teleportAck == player:GetNWInt("GarryCraftTeleport")
    for entry in pairs(entries) do
        if entry.kind == "avatar" and not avatarReady then
            if IsValid(entry.entity) then retireEntity(entry) end
        elseif not IsValid(entry.entity) then
            if GC.RenderTexture(entry.batch.texture) then create(entry) end
        end
    end
    removeEntities()
end)
hook.Add("ShutDown", "GarryCraftSourceModelCleanup", function()
    if IsValid(manual) then manual:Remove() end
    GC.ClearSourceModels()
    removeEntities()
end)
