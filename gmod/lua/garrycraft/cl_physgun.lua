local GC = GarryCraft

-- Keep item selection separate from weapon readiness during network delivery.
function GC.PhysgunEquipped()
    local player = LocalPlayer()
    local state = GC.State
    return IsValid(player) and player:GetNWBool("GarryCraft") and player:Alive() and state ~= nil
        and state.session == player:GetNWString("GarryCraftSession")
        and state.teleportAck == player:GetNWInt("GarryCraftTeleport")
        and state.physgunEquipped == true
end

function GC.PhysgunActive(player)
    local weapon = player:GetActiveWeapon()
    return GC.PhysgunEquipped() and not GC.ScreenOpen and not vgui.CursorVisible()
        and player:GetNWBool("GarryCraftPhysgun") and IsValid(weapon) and weapon:GetClass() == "weapon_physgun"
end

function GC.PhysgunHolding(player)
    return GC.PhysgunActive(player) and IsValid(player:GetNWEntity("GarryCraftPhysgunHeld"))
end

-- Keep Source's native sway, but attach it to the same interpolated camera as the Minecraft scene.
hook.Add("CalcViewModelView", "GarryCraftPhysgunCamera", function(_, _, oldPosition, oldAngles, position, angles)
    local player = LocalPlayer()
    if not IsValid(player) or not GC.PhysgunActive(player) or not GC.ViewOrigin or not GC.ViewAngles then return end
    local offset, rotation = WorldToLocal(position, angles, oldPosition, oldAngles)
    return LocalToWorld(offset, rotation, GC.ViewOrigin, GC.ViewAngles)
end)
