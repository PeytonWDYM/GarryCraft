local GC = GarryCraft
-- Capture sprint before Source movement processing can remove the button.
local sprint = false
hook.Add("CreateMove", "GarryCraftSprint", function(command)
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    local down = command:KeyDown(IN_SPEED)
    if down == sprint then return end
    sprint = down
    net.Start("garrycraft_sprint")
    net.WriteBool(down)
    net.SendToServer()
end)
local slot = 0

hook.Add("Move", "GarryCraftMovement", function(player, movement)
    if not player:GetNWBool("GarryCraft") then return end
    if not player:Alive() then return end
    if GC.State and GC.State.teleportAck == player:GetNWInt("GarryCraftTeleport") then
        movement:SetOrigin(GC.ToSource(GC.State.x, GC.State.y, GC.State.z))
    end
    movement:SetVelocity(vector_origin)
    return true
end)

hook.Add("PreDrawViewModel", "GarryCraftHideSourceWeapon", function()
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then return true end
end)

hook.Add("DrawPhysgunBeam", "GarryCraftHidePhysgunEffects", function(player)
    if player:GetNWBool("GarryCraft") then return false end
end)

hook.Add("PlayerBindPress", "GarryCraftSlots", function(player, bind, pressed)
    if not player:GetNWBool("GarryCraft") or not pressed then return end
    local selected = string.match(bind, "^slot(%d)$")
    if selected then slot = tonumber(selected) - 1
    elseif bind == "invnext" then slot = (slot + 1) % 9
    elseif bind == "invprev" then slot = (slot + 8) % 9
    else return end
    net.Start("garrycraft_slot")
    net.WriteUInt(slot, 4)
    net.SendToServer()
    return true
end)

hook.Add("HUDPaint", "GarryCraftStatus", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    if GC.OverlayReady then return end
    local text = "GarryCraft: waiting for Minecraft"
    if GC.State then text = string.format("GarryCraft  |  Health %.0f  |  Food %d  |  Slot %d", GC.State.health, GC.State.food, slot + 1) end
    draw.SimpleText(text, "DermaDefaultBold", 24, ScrH() - 32, color_white)
end)
