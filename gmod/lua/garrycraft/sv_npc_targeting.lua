local GC = GarryCraft
local owner
local creative = false
local npcs = {}
local relationships = {}

local function restoreRelationships()
    if IsValid(owner) then
        for npc, relationship in pairs(relationships) do
            if IsValid(npc) then npc:AddEntityRelationship(owner, relationship.disposition, relationship.priority) end
        end
    end
    relationships = {}
end

function GC.NpcTargetingStop()
    restoreRelationships()
    owner = nil
    creative = false
    npcs = {}
end

function GC.NpcTargetingBegin(player)
    GC.NpcTargetingStop()
    owner = player
    for _, entity in ipairs(ents.GetAll()) do
        if entity:IsNPC() and not entity.GarryCraftMirror then npcs[entity] = true end
    end
end

-- Mob targeting must retain the NPC's real allegiance while creative temporarily neutralizes the player relationship.
function GC.NpcPlayerDisposition(npc)
    local relationship = relationships[npc]
    return relationship and relationship.disposition or npc:Disposition(owner)
end

local function protect(npc)
    local disposition, priority = npc:Disposition(owner)
    if disposition == D_HT or disposition == D_FR then
        if not relationships[npc] then relationships[npc] = {disposition = disposition, priority = priority} end
        npc:AddEntityRelationship(owner, D_NU, priority)
    end
    -- Forget only the player. Other enemies and friendly interactions remain available to native AI.
    local targetingOwner = npc:GetEnemy() == owner
    npc:ClearEnemyMemory(owner)
    if targetingOwner then
        npc:SetEnemy(NULL)
        npc:ClearSchedule()
    end
end

function GC.NpcTargetingAccept(state)
    local nextCreative = state.linked and not state.reference and state.gameMode == "creative"
    if creative and not nextCreative then restoreRelationships() end
    creative = nextCreative
    if not creative then return end
    for npc in pairs(npcs) do
        if IsValid(npc) then protect(npc) else npcs[npc] = nil relationships[npc] = nil end
    end
end

hook.Add("OnEntityCreated", "GarryCraftNpcTargeting", function(entity)
    if not IsValid(owner) or not entity:IsNPC() then return end
    -- NPC disposition and spawn flags are available after Spawn completes.
    timer.Simple(0, function()
        if not IsValid(owner) or not IsValid(entity) or not entity:IsNPC() or entity.GarryCraftMirror then return end
        npcs[entity] = true
        if creative then protect(entity) end
    end)
end)

hook.Add("ShutDown", "GarryCraftNpcTargetingCleanup", GC.NpcTargetingStop)
