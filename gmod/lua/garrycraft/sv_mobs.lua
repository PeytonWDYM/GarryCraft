local GC = GarryCraft
local targets = {}
local damage = {}
local sequence = 0
local owner
local nextRelationships = 0
local tick = -1

function GC.MobsStop()
    for _, target in pairs(targets) do if IsValid(target) then target:Remove() end end
    targets = {}
    damage = {}
    sequence = 0
    owner = nil
    tick = -1
end

function GC.MobsBegin(player)
    GC.MobsStop()
    owner = player
end

function GC.MobDamage() return damage end
function GC.MobTarget(uuid) return targets[uuid] end

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
    if RealTime() < nextRelationships then return end
    nextRelationships = RealTime() + .5
    for _, npc in ipairs(ents.FindInSphere(owner:GetPos(), 3072)) do
        if npc:IsNPC() and not npc.GarryCraftMirror then
            for _, target in pairs(targets) do
                local hostile = target.GarryCraftEnemy or npc:Disposition(owner) == D_HT
                npc:AddEntityRelationship(target, hostile and D_HT or D_NU, 80)
                if hostile then
                    local sight = util.TraceLine({start = npc:EyePos(), endpos = target:WorldSpaceCenter(),
                        mask = MASK_SHOT, filter = {npc, target}})
                    if not sight.Hit then
                        npc:UpdateEnemyMemory(target, target:GetPos())
                        local enemy = npc:GetEnemy()
                        if not IsValid(enemy) or npc:GetPos():DistToSqr(target:GetPos()) < npc:GetPos():DistToSqr(enemy:GetPos()) then
                            npc:SetEnemy(target)
                            npc:SetNPCState(NPC_STATE_COMBAT)
                        end
                    end
                end
            end
        end
    end
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
