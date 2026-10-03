local GC = GarryCraft
local acknowledged = 0
local session
local applied = 0

function GC.EntitiesBegin(nextSession)
    session = nextSession
    acknowledged = 0
    applied = 0
end

function GC.EntitiesAck() return acknowledged end
function GC.EntitiesApplied() return applied end

-- Creation IDs prevent an old hit from reaching a new entity with the same entity index.
function GC.EntitiesHit(player, state)
    if state.session ~= session then return end
    for _, hit in ipairs(state.entityHits) do
        if hit.id > acknowledged then
            local entity = Entity(hit.entity)
            if IsValid(entity) and entity:GetCreationID() == hit.generation then
                local damage = DamageInfo()
                local attacker = GC.MobTarget(hit.attacker)
                damage:SetDamage(GC.DamageScale("units") * (hit.damage * GC.DamageScale(hit.attacker ~= "" and "mobToSource" or "playerToSource")
                    + hit.environmentDamage * GC.DamageScale("environment")))
                damage:SetAttacker(IsValid(attacker) and attacker or player)
                damage:SetInflictor(IsValid(attacker) and attacker or player:GetWeapon("weapon_garrycraft"))
                damage:SetDamageType(hit.explosion and DMG_BLAST or hit.fire and DMG_BURN or hit.projectile and DMG_BULLET or DMG_SLASH)
                local direction = GC.DirectionToSource(hit.pushX, hit.pushY, hit.pushZ)
                damage:SetDamageForce(hit.explosion and vector_origin or direction * hit.power * 100)
                damage:SetDamagePosition(entity:WorldSpaceCenter())
                entity:TakeDamageInfo(damage)
                if hit.explosion then
                    local physics = entity:GetPhysicsObject()
                    if IsValid(physics) and physics:IsMotionEnabled() then physics:Wake() physics:AddVelocity(direction * 20)
                    else entity:SetVelocity(direction * 20) end
                end
                applied = applied + 1
            end
            acknowledged = hit.id
        end
    end
end

function GC.EntityTargets(player)
    local actors = {}
    for _, entity in ipairs(ents.FindInSphere(player:GetPos(), 1024)) do
        if entity ~= player and not entity.GarryCraftMirror and entity:IsSolid() and not entity:IsWorld()
                and entity:GetClass() ~= "gc_block" and entity:GetClass() ~= "gc_fixture" and entity:GetClass() ~= "gc_physics_block"
                and bit.band(entity:GetSolidFlags(), FSOLID_TRIGGER) == 0 then
            local minimum, maximum = entity:WorldSpaceAABB()
            local position = GC.ToMinecraft(Vector((minimum.x + maximum.x) / 2, (minimum.y + maximum.y) / 2, minimum.z))
            actors[#actors + 1] = {id = entity:EntIndex(), generation = entity:GetCreationID(),
                name = entity:GetName() ~= "" and entity:GetName() or entity:GetClass(),
                x = position[1], y = position[2], z = position[3], yaw = -entity:GetAngles().y - 90,
                width = math.max(maximum.x - minimum.x, maximum.y - minimum.y) / 32,
                height = (maximum.z - minimum.z) / 32, npc = entity:IsNPC()}
        end
    end
    return actors
end
