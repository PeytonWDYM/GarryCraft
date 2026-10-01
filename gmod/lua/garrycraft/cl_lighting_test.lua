local GC = GarryCraft
local request, phase, ready
local samples = {}

hook.Add("Think", "GarryCraftLightingTest", function()
    local state = GC.State
    if not state or not state.lightingTestRequest or state.lightingTestRequest == "" then return end
    if request ~= state.lightingTestRequest then request, samples, phase = state.lightingTestRequest, {}, nil end
    if phase ~= state.lightingTestPhase then phase, ready = state.lightingTestPhase, RealTime() + 1 end
    if phase == "prepare" or phase == "waiting" or phase == "done" or RealTime() < ready or samples[phase] then return end
    local probe = GC.ToSource(35.5, -2.5, -.5)
    local model = GC.ModelLights(probe)
    local floor = render.ComputeDynamicLighting(GC.ToSource(36.5, -3.99, -.5), Vector(0, 0, 1))
    samples[phase] = {lights = GC.LightReport(), modelLights = #model, floorLight = {floor.x, floor.y, floor.z},
        camera = {state.x, state.y, state.z}, probe = tostring(probe)}
    file.Write("garrycraft-lighting-source.json", util.TableToJSON({request = request, samples = samples}))
end)
