local GC = GarryCraft
local owner
local grantedPhysgun = false
local active = false
local acceptedAt = -math.huge

local function select(enabled)
    if enabled == active then return end
    owner:DropObject()
    active = enabled
    owner:SetNWBool("GarryCraftPhysgun", enabled)
    owner:SetNWEntity("GarryCraftPhysgunHeld", NULL)
    if enabled then
        if not owner:HasWeapon("weapon_physgun") then
            owner:Give("weapon_physgun")
            grantedPhysgun = true
        end
        owner:SelectWeapon("weapon_physgun")
    else
        owner:SelectWeapon("weapon_garrycraft")
    end
end

function GC.PhysgunStop()
    if IsValid(owner) then
        if active then select(false) end
        owner:SetNWBool("GarryCraftPhysgun", false)
        owner:SetNWEntity("GarryCraftPhysgunHeld", NULL)
        if grantedPhysgun then owner:StripWeapon("weapon_physgun") end
    end
    owner = nil
    grantedPhysgun = false
    active = false
    acceptedAt = -math.huge
end

function GC.PhysgunBegin(player)
    GC.PhysgunStop()
    owner = player
    player:SetNWBool("GarryCraftPhysgun", false)
    player:SetNWEntity("GarryCraftPhysgunHeld", NULL)
end

function GC.PhysgunReset()
    if IsValid(owner) and active then select(false) end
    acceptedAt = -math.huge
end

-- Minecraft selects the item. The installed Source weapon owns all prop operations.
function GC.PhysgunAccept(state)
    acceptedAt = RealTime()
    select(state.physgunEquipped == true and state.linked and not state.reference
        and not state.screenOpen and state.health > 0 and owner:Alive()
        and state.teleportAck == owner:GetNWInt("GarryCraftTeleport"))
end

-- Call before the bridge removes attack buttons or clears analog movement.
function GC.PhysgunCommand(command)
    if active and (not owner:Alive() or RealTime() - acceptedAt > 0.25) then select(false) end
    if active then
        command:SelectWeapon(owner:GetWeapon("weapon_physgun"))
        return true
    end
    command:RemoveKey(IN_USE)
    command:RemoveKey(IN_RELOAD)
    command:RemoveKey(IN_WEAPON1)
    command:RemoveKey(IN_WEAPON2)
    command:SetMouseWheel(0)
    return false
end

hook.Add("OnPhysgunPickup", "GarryCraftPhysgunHeld", function(player, entity)
    if player == owner and active then player:SetNWEntity("GarryCraftPhysgunHeld", entity) end
end)

hook.Add("PhysgunDrop", "GarryCraftPhysgunHeld", function(player)
    if player == owner then player:SetNWEntity("GarryCraftPhysgunHeld", NULL) end
end)

-- These bodies mirror Minecraft sections. Moving them would separate collision from the world.
hook.Add("PhysgunPickup", "GarryCraftProtectBlockCollision", function(player, entity)
    if player == owner and active and entity:GetClass() == "gc_block" then return false end
end)

hook.Add("CanPlayerUnfreeze", "GarryCraftProtectBlockCollision", function(player, entity)
    if player == owner and active and entity:GetClass() == "gc_block" then return false end
end)

local function release(player)
    if player == owner then GC.PhysgunReset() end
end
hook.Add("PlayerDeath", "GarryCraftPhysgunRelease", release)
hook.Add("PlayerSilentDeath", "GarryCraftPhysgunRelease", release)
