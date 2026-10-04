-- Failures: collision bodies churn on light updates, section edits rebuild unchanged
-- batches, edits never arrive, or complete frame intervals exceed the idle distribution.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
local run = {frames = {}, phase = "idle"}
GC.FrameHitchTest = run
local previous
hook.Add("PreRender", "GarryCraftFrameHitchTest", function()
    local now = SysTime()
    if previous then run.frames[#run.frames + 1] = {ms = (now - previous) * 1000, phase = run.phase} end
    previous = now
end)
function run.Mark(phase) run.phase = phase end
function run.Finish()
    hook.Remove("PreRender", "GarryCraftFrameHitchTest")
    run.blocks = GC.BlockRenderReport()
    run.meshes = garrycraft_bridge.mesh_stats()
    run.completed = GC.State and GC.State.linked
    file.Write("garrycraft-frame-hitches.json", util.TableToJSON(run))
end
