local GC = GarryCraft
local targets = {}
local damage = {}
local sequence = 0
local owner
local nextRelationships = 0
local tick = -1
local npcs, mobTargets = {}, {}
local npcIndex, targetIndex = 1, 1
local scans = {maximumTraces = 0, maximumPairs = 0}

function GC.MobsStop()
    for _, target in pairs(targets) do if IsValid(target) then target:Remove() end end
    targets = {}
    damage = {}
    sequence = 0
    owner = nil
    tick = -1
    nextRelationships = 0
    npcs, mobTargets = {}, {}
    npcIndex, targetIndex = 1, 1
    scans = {maximumTraces = 0, maximumPairs = 0}
end

function GC.MobsBegin(player)
    GC.MobsStop()
    owner = player
end

function GC.MobDamage() return damage end
function GC.MobTarget(uuid) return targets[uuid] end
function GC.MobScanReport() return scans end

-- Bullseyes give Source NPCs a native aim target. Minecraft retains mob health, movement, and AI.
function GC.MobsAccept(state)
    if state.tick == tick then return end
    tick = state.tick
    while damage[1] and damage[1].id <= state.mobDamageAck do table.remove(damage, 1) end
    local live = {}
    for _, mob in ipairs(state.mobs) do
        live[mob.uuid] = true
        local target = targets[mob.uuid]
        if not IsValid(target) then
            target = ents.Create("npc_bullseye")
            target.GarryCraftMirror = true
            target.GarryCraftMob = mob.uuid
            target.GarryCraftRelationships = setmetatable({}, {__mode = "k"})
            target:SetKeyValue("spawnflags", "0")
            target:SetPos(GC.ToSource(mob.x, mob.y + mob.height * .5, mob.z))
            target:Spawn()
            target:SetNoDraw(true)
            target:SetMoveType(MOVETYPE_NONE)
            target:SetSolid(SOLID_BBOX)
            targets[mob.uuid] = target
        end
        target:SetHealth(100000)
        target:SetPos(GC.ToSource(mob.x, mob.y + mob.height * .5, mob.z))
        target:SetCollisionBounds(Vector(-mob.width * 16, -mob.width * 16, -mob.height * 16), Vector(mob.width * 16, mob.width * 16, mob.height * 16))
        target.GarryCraftEnemy = mob.enemy
    end
    for uuid, target in pairs(targets) do
        if not live[uuid] then if IsValid(target) then target:Remove() end targets[uuid] = nil end
    end
    if npcIndex > #npcs and RealTime() >= nextRelationships then
        nextRelationships = RealTime() + .5
        npcs, mobTargets = {}, {}
        npcIndex, targetIndex = 1, 1
        for _, npc in ipairs(ents.FindInSphere(owner:GetPos(), 3072)) do
            if npc:IsNPC() and not npc.GarryCraftMirror then npcs[#npcs + 1] = npc end
        end
        for _, target in pairs(targets) do mobTargets[#mobTargets + 1] = target end
        if #mobTargets == 0 then npcIndex = #npcs + 1 end
    end
    -- Spread engine calls over server ticks. Large groups cannot issue all sight traces at once.
    local examined, traces = 0, 0
    while npcIndex <= #npcs and examined < 32 and traces < 12 do
        local npc, target = npcs[npcIndex], mobTargets[targetIndex]
        targetIndex = targetIndex + 1
        if targetIndex > #mobTargets then npcIndex = npcIndex + 1 targetIndex = 1 end
        examined = examined + 1
        if IsValid(npc) and IsValid(target) then
            local hostile = target.GarryCraftEnemy or GC.NpcPlayerDisposition(npc) == D_HT
            local disposition = hostile and D_HT or D_NU
            if target.GarryCraftRelationships[npc] ~= disposition then
                npc:AddEntityRelationship(target, disposition, 80)
                target.GarryCraftRelationships[npc] = disposition
            end
            if hostile then
                local enemy = npc:GetEnemy()
                local closer = not IsValid(enemy) or npc:GetPos():DistToSqr(target:GetPos()) < npc:GetPos():DistToSqr(enemy:GetPos())
                if enemy == target or closer then
                    traces = traces + 1
                    local sight = util.TraceLine({start = npc:EyePos(), endpos = target:WorldSpaceCenter(), mask = MASK_SHOT, filter = {npc, target}})
                    if not sight.Hit then
                        npc:UpdateEnemyMemory(target, target:GetPos())
                        if closer then npc:SetEnemy(target) npc:SetNPCState(NPC_STATE_COMBAT) end
                    end
                end
            end
        end
    end
    scans.maximumTraces = math.max(scans.maximumTraces, traces)
    scans.maximumPairs = math.max(scans.maximumPairs, examined)
    scans.pendingPairs = math.max(0, (#npcs - npcIndex + 1) * #mobTargets - targetIndex + 1)
end

hook.Add("EntityTakeDamage", "GarryCraftMobDamage", function(entity, hit)
    if not entity.GarryCraftMirror then return end
    local attacker = hit:GetAttacker()
    sequence = sequence + 1
    damage[#damage + 1] = {id = sequence, uuid = entity.GarryCraftMob,
        amount = hit:GetDamage() * GC.DamageScale("sourceToMob"),
        attacker = IsValid(attacker) and attacker:EntIndex() or 0,
        generation = IsValid(attacker) and attacker:GetCreationID() or 0}
    return true
end)

hook.Add("ShutDown", "GarryCraftMobCleanup", GC.MobsStop)
