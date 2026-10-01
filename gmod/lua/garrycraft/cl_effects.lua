local GC = GarryCraft
local selection = {}
local cracks = {}
local revision
local request
local peak = 0

function GC.ClearBlockEffects()
    GC.DestroyRenderMeshes(cracks)
    cracks, selection, revision = {}, {}, nil
end
function GC.AcceptBlockEffects(scene, body)
    selection = scene.selection
    if revision ~= scene.cracks.revision then
        GC.DestroyRenderMeshes(cracks)
        cracks = GC.BuildRenderMeshes(scene.cracks.batches, false, true, body)
        revision = scene.cracks.revision
    end
end
hook.Add("PostDrawTranslucentRenderables", "GarryCraftBlockEffects", function(depth, skybox)
    if depth or skybox or GC.VideoReset or not GC.State or not GC.State.linked then return end
    if not IsValid(LocalPlayer()) or not LocalPlayer():GetNWBool("GarryCraft") then return end
    local drawn = GC.DrawRenderMeshes(cracks, true)
    if request ~= GC.State.terrainTestRequest then request = GC.State.terrainTestRequest peak = 0 end
    if GC.State.terrainTestPhase == "breaking" then peak = math.max(peak, drawn) end
    for _, box in ipairs(selection) do
        local minimum, maximum = GC.ToSource(box[1], box[2], box[3]), GC.ToSource(box[4], box[5], box[6])
        render.DrawWireframeBox(Vector(), Angle(), Vector(minimum.x, maximum.y, minimum.z),
            Vector(maximum.x, minimum.y, maximum.z), Color(0, 0, 0, 180), false)
    end
end)
concommand.Add("garrycraft_effects_report", function()
    file.Write("garrycraft-effects.json", util.TableToJSON({request = request, crackVerticesDrawn = peak}))
end)
hook.Add("ShutDown", "GarryCraftBlockEffectsCleanup", GC.ClearBlockEffects)
