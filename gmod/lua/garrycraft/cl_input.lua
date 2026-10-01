local GC = GarryCraft
local nextSend = 0
local keyboard
local namedSession

local function sendEvent(key, text)
    net.Start("garrycraft_ui_event")
    net.WriteUInt(key or 0, 9)
    net.WriteString(text or "")
    net.SendToServer()
end

local special = {[KEY_ENTER] = 40, [KEY_BACKSPACE] = 42, [KEY_TAB] = 43, [KEY_UP] = 82,
    [KEY_DOWN] = 81, [KEY_LEFT] = 80, [KEY_RIGHT] = 79, [KEY_HOME] = 74, [KEY_END] = 77,
    [KEY_DELETE] = 76, [KEY_PAGEUP] = 75, [KEY_PAGEDOWN] = 78}

local function openKeyboard()
    keyboard = vgui.Create("EditablePanel")
    keyboard:SetSize(1, 1)
    keyboard:SetPos(-10, -10)
    keyboard:SetAlpha(0)
    keyboard:MakePopup()
    keyboard:SetMouseInputEnabled(false)
    local entry = vgui.Create("DTextEntry", keyboard)
    entry:Dock(FILL)
    entry:RequestFocus()
    entry:SetUpdateOnType(true)
    function entry:AllowInput(text) sendEvent(0, text) return true end
    function entry:OnKeyCodeTyped(code)
        if special[code] then sendEvent(special[code]) end
    end
end

-- E opens Minecraft's inventory. F5 uses Minecraft's three camera modes.
hook.Add("Think", "GarryCraftScreenInput", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then
        if keyboard then keyboard:Remove() keyboard = nil gui.EnableScreenClicker(false) end
        return
    end
    local session = LocalPlayer():GetNWString("GarryCraftSession")
    if session ~= namedSession then
        namedSession = session
        local names = {}
        for _, npc in pairs(list.Get("NPC")) do
            names[npc.Name] = language.GetPhrase(string.gsub(npc.Name, "^#", ""))
        end
        net.Start("garrycraft_damage_names")
        net.WriteTable(names)
        net.SendToServer()
    end
    local screen = GC.State and GC.State.screenOpen or false
    if GC.ScreenOpen ~= screen then
        GC.ScreenOpen = screen
        gui.EnableScreenClicker(screen)
        if screen then openKeyboard()
        elseif keyboard then keyboard:Remove() keyboard = nil end
    end
    if RealTime() < nextSend then return end
    nextSend = RealTime() + 0.025
    local width, height = ScrW(), ScrH()
    if width == 0 or height == 0 then return end
    local x, y = gui.MousePos()
    net.Start("garrycraft_controls")
    net.WriteBool(input.IsKeyDown(KEY_F5))
    net.WriteBool(input.IsKeyDown(KEY_E))
    net.WriteBool(input.IsKeyDown(KEY_ESCAPE))
    net.WriteBool(input.IsKeyDown(KEY_T))
    net.WriteFloat(x / width)
    net.WriteFloat(y / height)
    net.WriteBool(input.IsMouseDown(MOUSE_LEFT))
    net.WriteBool(input.IsMouseDown(MOUSE_RIGHT))
    net.WriteUInt(width, 13)
    net.WriteUInt(height, 13)
    net.SendToServer()
end)

hook.Add("PlayerBindPress", "GarryCraftInventoryBind", function(player, bind)
    if player:GetNWBool("GarryCraft") and (bind == "+use" or bind == "messagemode" or bind == "messagemode2"
        or string.find(bind, "jpeg", 1, true)) then return true end
end)

hook.Add("StartChat", "GarryCraftChat", function()
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then return true end
end)

hook.Add("OnPauseMenuShow", "GarryCraftCloseScreen", function()
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then sendEvent(41) return false end
end)
