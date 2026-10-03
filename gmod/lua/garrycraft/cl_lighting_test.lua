local GC = GarryCraft
local request, phase, ready
local samples = {}
local capture
local projector
local comparison
local shadowsBeforeTest

local function restoreShadows()
    if shadowsBeforeTest then
        RunConsoleCommand("garrycraft_source_shadows", shadowsBeforeTest)
        shadowsBeforeTest = nil
    end
    capture = nil
end
hook.Add("ShutDown", "GarryCraftLightingTestCleanup", restoreShadows)

-- Opt-in engine shadow-map probe. Compare captures with 0 (off), 1 (shadows), and 2 (light only).
concommand.Add("garrycraft_test_depthshadow", function(_, _, args)
    if projector then projector:Remove() projector = nil end
    if comparison then RunConsoleCommand("garrycraft_source_shadows", comparison.shadows) comparison = nil end
    local compare = args[1] == "compare"
    local mode = compare and 1 or tonumber(args[1]) or 0
    if mode == 0 then return end
    projector = ProjectedTexture()
    projector:SetTexture("effects/flashlight001")
    projector:SetFOV(70)
    projector:SetNearZ(4)
    projector:SetFarZ(1024)
    projector:SetBrightness(4)
    projector:SetColor(Color(255, 255, 255))
    projector:SetEnableShadows(mode == 1)
    if compare then
        comparison = {ready = RealTime() + .5, shadows = GetConVar("garrycraft_source_shadows"):GetString(),
            session = GC.State.session, samples = {}}
        RunConsoleCommand("garrycraft_source_shadows", "0")
    end
end)

hook.Add("PreDrawOpaqueRenderables", "GarryCraftLightingDepthProbe", function(depth, skybox)
    if depth or skybox or not projector then return end
    if not GC.State or not GC.State.linked then
        projector:Remove() projector = nil
        if comparison then RunConsoleCommand("garrycraft_source_shadows", comparison.shadows) comparison = nil end
        return
    end
    if not GC.RenderFeet then return end
    local target = GC.RenderFeet
    local position = target + Vector(128, 0, 160)
    projector:SetPos(position)
    projector:SetAngles((target - position):Angle())
    projector:Update()
end)

hook.Add("PostRender", "GarryCraftLightingDepthEvidence", function()
    if not comparison or RealTime() < comparison.ready then return end
    local phase = comparison.samples.shadow and "light" or "shadow"
    render.CapturePixels()
    local pixels = {}
    for y = 1, 18 do for x = 1, 32 do
        local r, g, b = render.ReadPixel(math.floor(ScrW() * x / 33), math.floor(ScrH() * y / 19))
        pixels[#pixels + 1] = .2126 * r + .7152 * g + .0722 * b
    end end
    file.CreateDir("garrycraft-lighting")
    local path = "garrycraft-lighting/depth-" .. phase .. ".png"
    file.Write(path, render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
    comparison.samples[phase] = {pixels = pixels, screenshot = path, origin = tostring(GC.ViewOrigin),
        angles = tostring(GC.ViewAngles), avatar = GC.AvatarReport()}
    if phase == "shadow" then
        projector:SetEnableShadows(false)
        comparison.ready = RealTime() + .5
        return
    end
    local a, b = comparison.samples.shadow, comparison.samples.light
    comparison.samePose = a.origin == b.origin and a.angles == b.angles
    comparison.darkenedPixels = 0
    for index, pixel in ipairs(a.pixels) do
        if b.pixels[index] - pixel > 5 then comparison.darkenedPixels = comparison.darkenedPixels + 1 end
    end
    file.Write("garrycraft-depthshadow-source.json", util.TableToJSON(comparison))
    projector:Remove() projector = nil
    RunConsoleCommand("garrycraft_source_shadows", comparison.shadows)
    comparison = nil
end)
hook.Add("ShutDown", "GarryCraftLightingDepthProbeCleanup", function()
    if projector then projector:Remove() end
    if comparison then RunConsoleCommand("garrycraft_source_shadows", comparison.shadows) end
end)

hook.Add("Think", "GarryCraftLightingTest", function()
    local state = GC.State
    if not state or not state.linked or not LocalPlayer():GetNWBool("GarryCraft")
            or not state.lightingTestRequest or state.lightingTestRequest == "" then
        restoreShadows() request, phase = nil, nil return
    end
    if request ~= state.lightingTestRequest then
        restoreShadows()
        request, samples, phase = state.lightingTestRequest, {}, nil
        shadowsBeforeTest = GetConVar("garrycraft_source_shadows"):GetString()
    end
    if phase ~= state.lightingTestPhase then
        phase, ready = state.lightingTestPhase, RealTime() + 1
        if phase == "shadowOff" then RunConsoleCommand("garrycraft_source_shadows", "0") end
        if phase == "shadowOn" then RunConsoleCommand("garrycraft_source_shadows", "1") end
        if phase == "done" then restoreShadows() end
    end
    if phase == "prepare" or phase == "waiting" or phase == "done" or RealTime() < ready or samples[phase] then return end
    local room = phase == "enclosed" or phase == "roomTorch" or phase == "glass" or phase == "opened"
    -- Sample the lit floor beside the torch. The column top correctly occludes light from torches below it.
    local probe = room and GC.ToSource(43.5, -2.5, .5) or GC.ToSource(36.5, -3.99, -.5)
    local model = GC.ModelLights(probe)
    local floor = render.ComputeDynamicLighting(GC.ToSource(36.5, -3.99, -.5), Vector(0, 0, 1))
    samples[phase] = {lights = GC.LightReport(), modelLights = #model, floorLight = {floor.x, floor.y, floor.z},
        camera = {state.x, state.y, state.z}, view = tostring(GC.ViewOrigin), angles = tostring(GC.ViewAngles),
        probe = tostring(probe), water = GC.WaterLightingReport(GC.ToSource(35.5, -3.5, .5)),
        exposure = GC.LightingExposure(probe), avatar = GC.AvatarReport(), shadows = table.Copy(GC.ShadowReport())}
    capture = phase
end)

hook.Add("PostRender", "GarryCraftLightingEvidence", function()
    if not capture then return end
    local sample = samples[capture]
    render.CapturePixels()
    local total, count = 0, 0
    for y = 3, 6 do for x = 3, 6 do
        local r, g, b = render.ReadPixel(math.floor(ScrW() * x / 10), math.floor(ScrH() * y / 10))
        total, count = total + .2126 * r + .7152 * g + .0722 * b, count + 1
    end end
    sample.luminance = total / count
    if capture == "shadowOff" or capture == "shadowOn" then
        -- Source chooses each shadow's direction and receiver. Compare visible pixels without a second projection oracle.
        sample.shadowGrid = {columns = 96, rows = 54, width = ScrW(), height = ScrH(), pixels = {}}
        for y = 1, 54 do for x = 1, 96 do
            local r, g, b = render.ReadPixel(math.floor(ScrW() * x / 97), math.floor(ScrH() * y / 55))
            sample.shadowGrid.pixels[#sample.shadowGrid.pixels + 1] = .2126 * r + .7152 * g + .0722 * b
        end end
    end
    file.CreateDir("garrycraft-lighting")
    sample.screenshot = "garrycraft-lighting/" .. string.gsub(request, "[^%w%-]", "-") .. "-" .. capture .. ".png"
    file.Write(sample.screenshot, render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
    file.Write("garrycraft-lighting-source.json", util.TableToJSON({request = request, session = GC.State.session, samples = samples}))
    capture = nil
end)
