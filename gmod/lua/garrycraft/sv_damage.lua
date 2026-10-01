local GC = GarryCraft
local owner
local total = 0
local events = {}
local sequence = 0
local names = {}
util.AddNetworkString("garrycraft_damage_names")
net.Receive("garrycraft_damage_names", function(_, player)
    if player == owner then names = net.ReadTable() end
end)

function GC.DamageBegin(player)
    owner = player
    total = 0
    events = {}
    sequence = 0
end

function GC.DamageStop() owner = nil end
function GC.DamageTotal() return total end
function GC.DamageEvents() return events end
function GC.DamageAcknowledge(id)
    while events[1] and events[1].id <= id do table.remove(events, 1) end
end

local function attackerName(entity)
    if not IsValid(entity) or entity:IsWorld() then return "" end
    if entity:IsPlayer() then return entity:Nick() end
    if entity:GetName() ~= "" then return entity:GetName() end
    if entity.PrintName then return entity.PrintName end
    for _, npc in pairs(list.Get("NPC")) do
        if npc.Class == entity:GetClass() then
            return names[npc.Name] or string.gsub(npc.Name, "^#npc_", "")
        end
    end
    return string.gsub(entity:GetClass(), "_", " ")
end

-- A cumulative counter makes repeated bridge snapshots idempotent.
hook.Add("EntityTakeDamage", "GarryCraftDamage", function(entity, damage)
    if entity ~= owner then return end
    if not damage:IsDamageType(DMG_DROWN) and not damage:IsDamageType(DMG_FALL) then
        total = total + damage:GetDamage() / 5
        sequence = sequence + 1
        local kind = damage:IsDamageType(DMG_BULLET) and "bullet" or damage:IsDamageType(DMG_BLAST) and "blast" or "melee"
        events[#events + 1] = {id = sequence, amount = damage:GetDamage() / 5,
            attacker = attackerName(damage:GetAttacker()), kind = kind}
    end
    return true
end)
