-- Fresh linked gm_construct lab. Record steady and transition costs for forty exported emitters.
assert(game.SinglePlayer() and GarryCraft.State.linked, "Use an owned linked single-player lab")
local GC = GarryCraft
GC.LightingDensityTest = {}
local run = {started = RealTime(), session = GC.State.session, samples = {}}
local phase = "baseline"
local last = SysTime()
function GC.LightingDensityTest.Mark(name) phase = name end
function GC.LightingDensityTest.Finish()
    hook.Remove("Think", "GarryCraftLightingDensityTest")
    run.completed = true
    file.Write("garrycraft-lighting-density.json", util.TableToJSON(run))
    GC.LightingDensityTest = nil
end
hook.Add("Think", "GarryCraftLightingDensityTest", function()
    local now = SysTime()
    local blocks = GC.BlockRenderReport()
    run.samples[#run.samples+1] = {time = RealTime()-run.started, phase = phase, frameMs = (now-last)*1000,
        lights = blocks.lights, sections = blocks.sections, rebuilt = blocks.rebuilt, reused = blocks.reused,
        transferMs = blocks.transferMs, voxels = blocks.lighting.voxels}
    last = now
end)
