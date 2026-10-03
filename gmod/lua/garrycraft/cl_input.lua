local GC = GarryCraft
local keyboard
local session
local events = {}
local sequence, frame = 0, 0

local function event(key, text, scroll, button, down)
    local x, y = gui.MousePos()
    sequence = sequence + 1
    events[#events + 1] = {id = sequence, key = key or 0, text = text or "", scroll = scroll or 0,
        button = button or 0, down = down or false, mouseX = x / ScrW(), mouseY = y / ScrH()}
end
GC.QueueUiEvent = event
function GC.QueueWheel(delta) event(0, "", delta) end

local special = {[KEY_ENTER] = 40, [KEY_BACKSPACE] = 42, [KEY_TAB] = 43, [KEY_UP] = 82,
    [KEY_DOWN] = 81, [KEY_LEFT] = 80, [KEY_RIGHT] = 79, [KEY_HOME] = 74, [KEY_END] = 77,
    [KEY_DELETE] = 76, [KEY_PAGEUP] = 75, [KEY_PAGEDOWN] = 78}
local buttons = {[MOUSE_LEFT] = 1, [MOUSE_MIDDLE] = 2, [MOUSE_RIGHT] = 3}

local function openKeyboard()
    keyboard = vgui.Create("EditablePanel")
    keyboard:SetSize(ScrW(), ScrH())
    keyboard:SetPos(0, 0)
    keyboard:SetAlpha(0)
    keyboard:SetName("GarryCraftInput")
    keyboard:MakePopup()
    local entry = vgui.Create("DTextEntry", keyboard)
    function keyboard:OnMouseWheeled(delta) GC.QueueWheel(delta) return true end
    function keyboard:OnMousePressed(code)
        if buttons[code] then event(0, "", 0, buttons[code], true) self:MouseCapture(true) end
    end
    function keyboard:OnMouseReleased(code)
        if buttons[code] then event(0, "", 0, buttons[code], false) self:MouseCapture(false) end
        -- The full-screen mouse receiver can take focus from the hidden text entry.
        entry:RequestFocus()
    end
    entry:SetSize(1, 1)
    entry:SetPos(-10, -10)
    entry:SetName("GarryCraftTextInput")
    entry:SetMouseInputEnabled(false)
    entry:RequestFocus()
    entry:SetUpdateOnType(true)
    function entry:AllowInput(text) event(0, text) return true end
    function entry:OnKeyCodeTyped(code)
        -- Suppress Source text-entry actions, including Tab focus traversal and Enter.
        if special[code] then event(special[code]) return true end
    end
end

hook.Add("Think", "GarryCraftScreenInput", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:GetNWBool("GarryCraft") then
        if keyboard then keyboard:Remove() keyboard = nil gui.EnableScreenClicker(false) end
        GC.ScreenOpen = false
        session = nil
        return
    end
    local current = player:GetNWString("GarryCraftSession")
    if current ~= session then
        session = current
        events = {}
        sequence, frame = 0, 0
        GC.SelectedSlot = 0
        GC.InputAngles = nil
        local names = {}
        for _, npc in pairs(list.Get("NPC")) do
            names[npc.Name] = language.GetPhrase(string.gsub(npc.Name, "^#", ""))
        end
        net.Start("garrycraft_damage_names")
        net.WriteTable(names)
        net.SendToServer()
    end
    local screen = GC.State and GC.State.session == session and GC.State.screenOpen or false
    if GC.ScreenOpen ~= screen then
        GC.ScreenOpen = screen
        gui.EnableScreenClicker(screen)
        if screen then openKeyboard()
        elseif keyboard then keyboard:Remove() keyboard = nil end
    end
    if keyboard then keyboard:SetSize(ScrW(), ScrH()) end
end)

-- Lane 8 publishes look and UI input once per rendered frame from this client alone.
hook.Add("PreRender", "GarryCraftClientControls", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:GetNWBool("GarryCraft") or not GC.BridgePath or not session then return end
    local state = GC.State
    if state and state.session == session then
        while events[1] and events[1].id <= state.clientUiAck do table.remove(events, 1) end
    end
    local angles = GC.InputAngles or player:EyeAngles()
    local x, y = gui.MousePos()
    local acceptsButtons = GC.ScreenOpen or not vgui.CursorVisible()
    frame = frame + 1
    local controls = {version = 1, session = session, teleportSeq = player:GetNWInt("GarryCraftTeleport"),
        frame = frame, time = garrycraft_bridge.clock(), yaw = -angles.y - 90, pitch = angles.p,
        mouseX = x / ScrW(), mouseY = y / ScrH(), camera = input.IsKeyDown(KEY_F5),
        inventory = input.IsKeyDown(GC.PhysgunEquipped() and KEY_I or KEY_E), chat = input.IsKeyDown(KEY_T),
        attack = acceptsButtons and input.IsMouseDown(MOUSE_LEFT), use = acceptsButtons and input.IsMouseDown(MOUSE_RIGHT),
        shift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
        control = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
        alt = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
        viewportWidth = ScrW(), viewportHeight = ScrH(), slot = GC.SelectedSlot or 0, events = events}
    if GC.TestClientControls then GC.TestClientControls(controls) end
    garrycraft_bridge.send(8, util.TableToJSON(controls))
end)

hook.Add("PlayerBindPress", "GarryCraftInventoryBind", function(player, bind, pressed)
    if player:GetNWBool("GarryCraft") and ((bind == "+use" and pressed and not GC.PhysgunEquipped()) or bind == "messagemode" or bind == "messagemode2"
        or string.find(bind, "jpeg", 1, true)) then return true end
end)
hook.Add("StartChat", "GarryCraftChat", function()
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then return true end
end)
hook.Add("OnPauseMenuShow", "GarryCraftCloseScreen", function()
    if IsValid(LocalPlayer()) and LocalPlayer():GetNWBool("GarryCraft") then event(41) return false end
end)
