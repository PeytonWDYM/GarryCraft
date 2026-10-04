-- Failures: edits never reach Source, shared boundaries stay hidden, or
-- unchanged faces lose mesh ownership during neighboring edits.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
GC.RenderEditTest = {}
local camera = hook.GetTable().CalcView.GarryCraftCamera
function GC.RenderEditTest.View()
    hook.Add("CalcView", "GarryCraftCamera", function()
        GC.ViewOrigin, GC.ViewAngles = GC.ToSource(38, 5, 8), Angle(22, 90, 0)
        return {origin = GC.ViewOrigin, angles = GC.ViewAngles, fov = 75}
    end)
end
function GC.RenderEditTest.RestoreView() hook.Add("CalcView", "GarryCraftCamera", camera) end
function GC.RenderEditTest.Begin()
    local run = {started = RealTime(), frames = {}}
    GC.RenderEditTest.run = run
    hook.Add("PostRender", "GarryCraftRenderEditFrames", function()
        local report = GC.BlockRenderReport()
        run.frames[#run.frames + 1] = {time = RealTime() - run.started,
            vertices = report.vertices, ack = report.ack, models = GC.SourceModelReport()}
    end)
end
function GC.RenderEditTest.Finish()
    hook.Remove("PostRender", "GarryCraftRenderEditFrames")
    file.Write("garrycraft-render-edits/transitions.json", util.TableToJSON(GC.RenderEditTest.run))
end
function GC.RenderEditTest.Capture(label)
    local faces = {}
    for _, batch in ipairs(GC.BlockShadowMeshes()) do
        if batch.center:Distance(GC.ToSource(38, 3, 0)) < 400 then
            faces[#faces + 1] = {minimum = {batch.minimum:Unpack()}, maximum = {batch.maximum:Unpack()},
                normal = {batch.normal:Unpack()}, vertices = batch.vertices, geometry = batch.geometry,
                model = batch.sourceModel and batch.sourceModel.entity:EntIndex()}
        end
    end
    hook.Add("PostRender", "GarryCraftRenderEditCapture", function()
        hook.Remove("PostRender", "GarryCraftRenderEditCapture")
        file.CreateDir("garrycraft-render-edits")
        file.Write("garrycraft-render-edits/" .. label .. ".png", render.Capture({
            format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        file.Write("garrycraft-render-edits/" .. label .. ".json", util.TableToJSON({faces = faces,
            blocks = GC.BlockRenderReport(), arms = GC.PhysgunArmReport(), time = RealTime()}, true))
    end)
end
