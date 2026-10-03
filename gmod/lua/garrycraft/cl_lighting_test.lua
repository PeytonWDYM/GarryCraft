local GC = GarryCraft
local request, phase, ready
local samples = {}
local capture
local projector
local comparison
local planarBeforeTest
local shadowProbes

local function restorePlanar()
    if planarBeforeTest then
        RunConsoleCommand("garrycraft_planar_shadows", planarBeforeTest)
        planarBeforeTest = nil
    end
    capture, shadowProbes = nil, nil
end
hook.Add("ShutDown", "GarryCraftLightingTestCleanup", restorePlanar)

-- Opt-in engine shadow-map probe. Compare captures with 0 (off), 1 (shadows), and 2 (light only).
concommand.Add("garrycraft_test_depthshadow", function(_, _, args)
    if projector then projector:Remove() projector = nil end
    if comparison then RunConsoleCommand("garrycraft_planar_shadows", comparison.planar) comparison = nil end
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
        comparison = {ready = RealTime() + .5, planar = GetConVar("garrycraft_planar_shadows"):GetString(),
            session = GC.State.session, samples = {}}
        RunConsoleCommand("garrycraft_planar_shadows", "0")
    end
end)

hook.Add("PreDrawOpaqueRenderables", "GarryCraftLightingDepthProbe", function(depth, skybox)
    if depth or skybox or not projector then return end
    if not GC.State or not GC.State.linked then
        projector:Remove() projector = nil
        if comparison then RunConsoleCommand("garrycraft_planar_shadows", comparison.planar) comparison = nil end
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
    RunConsoleCommand("garrycraft_planar_shadows", comparison.planar)
    comparison = nil
end)
hook.Add("ShutDown", "GarryCraftLightingDepthProbeCleanup", function()
    if projector then projector:Remove() end
    if comparison then RunConsoleCommand("garrycraft_planar_shadows", comparison.planar) end
end)

hook.Add("Think", "GarryCraftLightingTest", function()
    local state = GC.State
    if not state or not state.linked or not LocalPlayer():GetNWBool("GarryCraft")
            or not state.lightingTestRequest or state.lightingTestRequest == "" then
        restorePlanar() request, phase = nil, nil return
    end
    if request ~= state.lightingTestRequest then
        restorePlanar()
        request, samples, phase = state.lightingTestRequest, {}, nil
        planarBeforeTest = GetConVar("garrycraft_planar_shadows"):GetString()
    end
    if phase ~= state.lightingTestPhase then
        phase, ready = state.lightingTestPhase, RealTime() + 1
        if phase == "shadowOff" then RunConsoleCommand("garrycraft_planar_shadows", "0") end
        if phase == "shadowOn" then RunConsoleCommand("garrycraft_planar_shadows", "1") end
        if phase == "done" then restorePlanar() end
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
    if phase == "shadowOn" then
        local receivers = {}
        for _, x in ipairs({50.999, 51, 51.001}) do
            local point = GC.ToSource(x, 5, .5)
            local receiver = garrycraft_bridge.shadow_receiver(point + Vector(0, 0, .5))
            receivers[#receivers + 1] = {x = x, found = receiver ~= nil, height = receiver and receiver.z or 0, expected = point.z}
        end
        samples[phase].seamReceivers = receivers
    end
    capture = phase
end)

hook.Add("PostDrawTranslucentRenderables", "GarryCraftLightingShadowProbes", function(depth, skybox)
    if depth or skybox or (phase ~= "shadowOff" and phase ~= "shadowOn") then return end
    local avatar = GC.ProjectShadowPoint(GC.RenderFeet + Vector(0, 0, 32), GC.RenderFeet)
    local feet = GC.ToSource(50.5, 5, 2.5)
    local top = feet + Vector(0, 0, 31.5)
    local direction = GC.ProjectShadowPoint(top, feet) - top
    -- Sample the projected top edge beyond the cube footprint, away from its visible black side.
    if math.abs(direction.x) >= math.abs(direction.y) then
        top.x = top.x + (direction.x >= 0 and 14 or -14)
    else
        top.y = top.y + (direction.y >= 0 and 14 or -14)
    end
    local block = GC.ProjectShadowPoint(top, feet)
    shadowProbes = {avatar = avatar:ToScreen(), block = block:ToScreen()}
    shadowProbes.avatar.world, shadowProbes.block.world = tostring(avatar), tostring(block)
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
        sample.shadowPixels = {}
        for name, probe in pairs(shadowProbes) do
            local sum = 0
            for oy = -4, 4 do for ox = -4, 4 do
                local r, g, b = render.ReadPixel(math.floor(probe.x) + ox * 2, math.floor(probe.y) + oy * 2)
                sum = sum + .2126 * r + .7152 * g + .0722 * b
            end end
            sample.shadowPixels[name] = {x = probe.x, y = probe.y, world = probe.world,
                visible = probe.visible, luminance = sum / 81}
        end
    end
    file.CreateDir("garrycraft-lighting")
    sample.screenshot = "garrycraft-lighting/" .. string.gsub(request, "[^%w%-]", "-") .. "-" .. capture .. ".png"
    file.Write(sample.screenshot, render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
    file.Write("garrycraft-lighting-source.json", util.TableToJSON({request = request, session = GC.State.session, samples = samples}))
    capture = nil
end)
