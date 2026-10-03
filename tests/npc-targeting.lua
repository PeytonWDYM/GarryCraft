-- Loaded only by Test-NpcTargeting.ps1 in an owned single-player lab.
assert(game.SinglePlayer(), "NPC targeting tests require single-player")
local owner = player.GetHumans()[1]
local test = {npcs = {}, trace = {}}
GarryCraft.NpcTargetingTest = test

function test.Spawn(name, class, disposition, priority)
    local npc = ents.Create(class)
    npc:SetName("garrycraft-targeting-" .. name)
    npc:SetPos(owner:GetPos() + Vector(128, #test.npcs * 64, 0))
    if class == "npc_citizen" then
        npc:SetModel("models/Humans/Group01/male_07.mdl")
        npc:SetKeyValue("spawnflags", "1048576")
    end
    npc:Spawn()
    npc:SetMoveType(MOVETYPE_NONE)
    npc:SetHealth(10000)
    if disposition then npc:AddEntityRelationship(owner, disposition, priority) end
    local original, originalPriority = npc:Disposition(owner)
    test.npcs[#test.npcs + 1] = {name = name, entity = npc, original = original, priority = originalPriority}
    return npc
end

test.hostile = test.Spawn("hostile", "npc_combine_s", D_HT, 137)
test.ally = test.Spawn("ally", "npc_citizen", D_LI, 71)
test.Spawn("fearful", "npc_citizen", D_FR, 83)
test.Spawn("neutral", "npc_citizen", D_NU, 62)
test.hostile:SetEnemy(owner)
test.hostile:UpdateEnemyMemory(owner, owner:GetPos())

function test.Snapshot(name)
    local rows = {}
    for _, entry in ipairs(test.npcs) do
        local npc = entry.entity
        local disposition, priority = npc:Disposition(owner)
        local mobs = {}
        for _, target in ipairs(ents.FindByClass("npc_bullseye")) do
            if target.GarryCraftMirror then mobs[#mobs + 1] = npc:Disposition(target) end
        end
        rows[#rows + 1] = {name = entry.name, disposition = disposition, priority = priority,
            health = npc:Health(),
            original = entry.original, originalPriority = entry.priority, enemyOwner = npc:GetEnemy() == owner,
            enemyAlly = npc:GetEnemy() == test.ally, visible = npc:Visible(owner), mobs = mobs}
    end
    file.Write("garrycraft-targeting-" .. name .. ".json", util.TableToJSON({npcs = rows,
        noTarget = owner:IsFlagSet(FL_NOTARGET), active = GarryCraft.IsActive(), trace = test.trace}))
end

local nextSample = 0
hook.Add("Think", "GarryCraftNpcTargetingTrace", function()
    if RealTime() < nextSample then return end
    nextSample = RealTime() + .1
    test.trace[#test.trace + 1] = {time = RealTime(), phase = test.phase,
        hostileEnemy = test.hostile:GetEnemy() == owner, hostileDisposition = test.hostile:Disposition(owner)}
end)

function test.Stop()
    hook.Remove("Think", "GarryCraftNpcTargetingTrace")
    for _, entry in ipairs(test.npcs) do entry.entity:Remove() end
    GarryCraft.NpcTargetingTest = nil
end
