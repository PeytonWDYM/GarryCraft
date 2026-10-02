local function setEnabled(value)
    net.Start("garrycraft_toggle")
    net.WriteBool(value)
    net.SendToServer()
end
local function controls(panel)
    panel:Help("Minecraft starts when you enter a single-player map. Each map retains its own world and inventory.")
    local label = panel:Help("")
    function label:Think() self:SetText(GetGlobalString("GarryCraftStatus", "Waiting for the local server")) end
    local enable = panel:Button("Enable GarryCraft and start automatically")
    function enable:DoClick() setEnabled(true) end
    local disable = panel:Button("Disable GarryCraft and return to normal play")
    function disable:DoClick() setEnabled(false) end
    panel:Help("Disable saves Minecraft and restores your Source weapon, movement, and frame limits. This choice persists across maps.")
end
hook.Add("PopulateToolMenu", "GarryCraftSettings", function()
    spawnmenu.AddToolMenuOption("Utilities", "GarryCraft", "GarryCraftRuntime", "GarryCraft", "", "", controls)
end)
concommand.Add("garrycraft_menu", function()
    local frame = vgui.Create("DFrame")
    frame:SetSize(440, 320)
    frame:Center()
    frame:SetTitle("GarryCraft")
    local panel = vgui.Create("DForm", frame)
    panel:Dock(FILL)
    panel:SetName("Play controls")
    controls(panel)
    frame:MakePopup()
end)
