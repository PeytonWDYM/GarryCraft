local GC = GarryCraft
local request, phase, started, nextWheel
local trace = {}
local completed
local overlayFrame
local overlayAges = {}
local textFocus = {}

local function typeSearch(text, edit)
    for _, panel in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if panel:GetName() == "GarryCraftInput" then
            local entry = panel:GetChildren()[1]
            -- A click can transfer keyboard focus to the full-screen mouse receiver.
            panel:RequestFocus()
            panel:OnMouseReleased(MOUSE_LEFT)
            local focused = entry:HasFocus()
            textFocus[#textFocus + 1] = {phase = phase, focused = focused}
            if focused then
                if edit then entry:OnKeyCodeTyped(KEY_BACKSPACE) end
                for character in string.gmatch(text, ".") do entry:AllowInput(character) end
            end
            return
        end
    end
    error("Creative search input panel is missing")
end

function GC.TestClientControls(controls)
    local state = GC.State
    if not state or not state.responsivenessRequest or not string.StartWith(state.responsivenessRequest, "responsiveness:") then return end
    if request ~= state.responsivenessRequest then
        request = state.responsivenessRequest
        started = RealTime()
        trace = {}
        completed = false
        overlayFrame = nil
        overlayAges = {}
        textFocus = {}
        RunConsoleCommand("garrycraft_fps_reset")
    end
    if completed then return end
    if phase ~= state.responsivenessPhase then
        phase = state.responsivenessPhase
        nextWheel = RealTime() + .5
        RunConsoleCommand("jpeg")
        if phase == "search" then typeSearch("stone", false) end
        if phase == "edit-search" then typeSearch("", true) end
    end
    controls.yaw = math.NormalizeAngle((RealTime() - started) * 120)
    controls.pitch = 0
    controls.camera, controls.inventory, controls.chat, controls.attack, controls.use = false, false, false, false, false
    controls.mouseX, controls.mouseY = .5, .5
    if (phase == "video" or phase == "creative") and RealTime() >= nextWheel then
        nextWheel = RealTime() + .2
        GC.QueueWheel(-1)
    end
    for _, event in ipairs(controls.events) do event.mouseX, event.mouseY = .5, .5 end
    trace[#trace + 1] = {phase = phase, time = RealTime() - started, inputFrame = state.clientInputFrame,
        ageMs = state.clientInputAgeMs}
    if overlayFrame ~= GC.OverlayFrame and GC.OverlayAgeMs then
        overlayFrame = GC.OverlayFrame
        overlayAges[#overlayAges + 1] = GC.OverlayAgeMs
    end
    if phase == "done" then
        completed = true
        file.Write("garrycraft-responsiveness-source.json", util.TableToJSON({request = request, completed = true,
            trace = trace, overlayAgesMs = overlayAges, textFocus = textFocus}))
        RunConsoleCommand("garrycraft_render_report")
        RunConsoleCommand("garrycraft_frame_report")
    end
end
