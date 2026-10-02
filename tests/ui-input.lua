-- Observe real VGUI callbacks. This fixture never queues bridge input.
local GC = GarryCraft
local request, phase, entry, panel
local trace, callbacks = {}, {}
local nextSample = 0

local function observeKeyboard()
    for _, candidate in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if candidate:GetName() == "GarryCraftInput" then
            panel = candidate
            for _, child in ipairs(panel:GetChildren()) do
                if child:GetClassName() == "TextEntry" or child:GetName() == "GarryCraftTextInput" then
                    if child == entry then return end
                    entry = child
                    local allow, key = entry.AllowInput, entry.OnKeyCodeTyped
                    function entry:AllowInput(text)
                        callbacks[#callbacks + 1] = {phase = phase, kind = "text", text = text, focused = vgui.GetKeyboardFocus() == self}
                        return allow(self, text)
                    end
                    function entry:OnKeyCodeTyped(code)
                        callbacks[#callbacks + 1] = {phase = phase, kind = "key", code = code, focused = vgui.GetKeyboardFocus() == self}
                        return key(self, code)
                    end
                    local pressed, released = panel.OnMousePressed, panel.OnMouseReleased
                    function panel:OnMousePressed(code)
                        callbacks[#callbacks + 1] = {phase = phase, kind = "mouse", code = code, down = true}
                        return pressed(self, code)
                    end
                    function panel:OnMouseReleased(code)
                        callbacks[#callbacks + 1] = {phase = phase, kind = "mouse", code = code, down = false}
                        return released(self, code)
                    end
                end
            end
        end
    end
end

hook.Add("Think", "GarryCraftUiInputFixture", function()
    local state = GC.State
    if not state or not string.StartWith(state.responsivenessRequest or "", "responsiveness:ui-input:") then return end
    if state.responsivenessRequest ~= request then
        request = state.responsivenessRequest
        trace, callbacks = {}, {}
    end
    phase = state.responsivenessPhase
    observeKeyboard()
    if RealTime() < nextSample and phase ~= "done" then return end
    nextSample = RealTime() + .1
    local focus = vgui.GetKeyboardFocus()
    trace[#trace + 1] = {phase = phase, time = RealTime(), screenOpen = GC.ScreenOpen,
        hasPanel = IsValid(panel), focused = IsValid(entry) and focus == entry,
        focusName = IsValid(focus) and focus:GetName() or "none", uiAck = state.clientUiAck}
    file.Write("garrycraft-ui-input-source.json", util.TableToJSON({request = request, completed = phase == "done",
        inputMethod = "VGUI callbacks from Windows SendInput", tabKey = KEY_TAB, mouseLeftKey = MOUSE_LEFT,
        callbacks = callbacks, trace = trace}))
    if phase == "done" then hook.Remove("Think", "GarryCraftUiInputFixture") end
end)
