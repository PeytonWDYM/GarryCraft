local GC = GarryCraft
local owner
local target
local sequence = 0
local deaths = 0

local function setTarget(player)
    sequence = sequence + 1
    target = player:GetPos()
    player:SetNWInt("GarryCraftTeleport", sequence)
    player:SetHull(Vector(-9.6, -9.6, 0), Vector(9.6, 9.6, 57.6))
    player:SetHullDuck(Vector(-9.6, -9.6, 0), Vector(9.6, 9.6, 48))
    player:Give("weapon_garrycraft")
    player:SelectWeapon("weapon_garrycraft")
end

function GC.RespawnBegin(player)
    owner = player
    sequence = 0
    deaths = 0
    setTarget(player)
end

function GC.RespawnStop()
    owner = nil
end

function GC.RespawnNewPeer()
    deaths = 0
    setTarget(owner)
end

function GC.RespawnTarget()
    return target, sequence
end

function GC.RespawnAccept(state)
    if state.teleportAck ~= sequence or not owner:Alive() then return false end
    if state.deaths > deaths then
        deaths = state.deaths
        owner:KillSilent()
        return false
    end
    return true
end

-- Wait until the gamemode has selected its real spawn and applied its player class.
hook.Add("PlayerSpawn", "GarryCraftRespawn", function(player)
    if player ~= owner then return end
    timer.Simple(0, function()
        if player == owner and IsValid(player) then setTarget(player) end
    end)
end)

local function died(player)
    if player ~= owner then return end
    timer.Simple(0.1, function()
        if player == owner and IsValid(player) and not player:Alive() then player:Spawn() end
    end)
end
hook.Add("PlayerDeath", "GarryCraftRespawn", died)
hook.Add("PlayerSilentDeath", "GarryCraftRespawn", died)
