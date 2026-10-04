-- Owned single-player fixture. Failures: probes inside neighboring solids, stale boundary
-- faces after removal, replacement flashes, or missing arms without a Source hands entity.
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
        local blocked = 0
        for _, batch in ipairs(GC.BlockShadowMeshes()) do
            if batch.center:Distance(GC.ToSource(38, 3, 1)) < 180 then
                local voxel = GC.VoxelLight(batch.probe or batch.center + batch.normal * .5)
                if voxel and (voxel.opaque or voxel.centerBlocked) then blocked = blocked + 1 end
            end
        end
        run.frames[#run.frames + 1] = {time = RealTime() - run.started, blockedProbes = blocked,
            blocks = GC.BlockRenderReport().ack}
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
            local probe = batch.probe or batch.center + batch.normal * .5
            local voxel = GC.VoxelLight(probe)
            faces[#faces + 1] = {minimum = {batch.minimum:Unpack()}, maximum = {batch.maximum:Unpack()},
                normal = {batch.normal:Unpack()}, probe = {probe:Unpack()}, voxel = voxel,
                vertices = batch.vertices, lighting = batch.lighting.colors}
        end
    end
    hook.Add("PostRender", "GarryCraftRenderEditCapture", function()
        hook.Remove("PostRender", "GarryCraftRenderEditCapture")
        file.CreateDir("garrycraft-render-edits")
        file.Write("garrycraft-render-edits/" .. label .. ".png", render.Capture({
            format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        file.Write("garrycraft-render-edits/" .. label .. ".json", util.TableToJSON({faces = faces,
            blocks = GC.BlockRenderReport(), arms = GC.PhysgunArmReport(), time = RealTime(),
            editedCell = GC.VoxelLight(GC.ToSource(37.5, 4.5, 1.5))}, true))
    end)
end
