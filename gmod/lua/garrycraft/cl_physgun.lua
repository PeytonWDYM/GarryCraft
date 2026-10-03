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

local viewmodelReport = {}
function GC.PhysgunViewmodelReport() return viewmodelReport end

-- Vanilla supplies the complete bob/hurt matrix. The installed model retains its bone animation.
hook.Add("CalcViewModelView", "GarryCraftPhysgunCamera", function()
    local player = LocalPlayer()
    if not IsValid(player) or not GC.PhysgunActive(player) or not GC.ViewOrigin or not GC.ViewAngles then return end
    local bob = Matrix()
    local fields = GC.State.nativeViewmodelPose
    for row = 1, 3 do for column = 1, 4 do bob:SetField(row, column, fields[(row - 1) * 4 + column]) end end
    local result, look = LocalToWorld(bob:GetTranslation(), bob:GetAngles(), GC.ViewOrigin, GC.ViewAngles)
    GC.PhysgunViewmodelOrigin, GC.PhysgunViewmodelAngles = result, look
    local observed = WorldToLocal(result, look, GC.ViewOrigin, GC.ViewAngles)
    viewmodelReport = {translationY = bob:GetTranslation().y,
        transformedOffset = {observed.x, observed.y, observed.z}, error = observed:Distance(bob:GetTranslation()),
        minecraftPose = fields, packetFrame = GC.State.frame, sourceFrame = FrameNumber(),
        viewOrigin = {GC.ViewOrigin.x, GC.ViewOrigin.y, GC.ViewOrigin.z},
        viewAngles = {GC.ViewAngles.p, GC.ViewAngles.y, GC.ViewAngles.r}}
    return result, look
end)
