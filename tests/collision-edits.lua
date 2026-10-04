-- Failures: merged boxes fill a removed cell, lose replacement collision, flatten
-- slabs or stairs, or replace native physics bodies when only voxel light changes.
assert(SERVER and game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
GC.CollisionEditTest = {samples = {}}
function GC.CollisionEditTest.Capture(label)
    local probes = {}
    for _, point in ipairs({{38.5,3.5}, {40.5,3.5}, {42.25,3.5}, {42.75,3.5}}) do
        local trace = util.TraceLine({start = GC.ToSource(point[1],10,point[2]),
            endpos = GC.ToSource(point[1],5,point[2]),
            filter = function(entity) return entity:GetClass() == "gc_block" end})
        probes[#probes + 1] = {hit = trace.Hit, y = GC.ToMinecraft(trace.HitPos)[2]}
    end
    local bodies = {}
    for _, entity in ipairs(ents.FindByClass("gc_block")) do
        bodies[#bodies + 1] = {id = entity:EntIndex(), creation = entity:GetCreationID(), convexes = #entity.Convexes}
    end
    GC.CollisionEditTest.samples[label] = {probes=probes, bodies=bodies, stats=GC.BlockCollisionReport and GC.BlockCollisionReport()}
    file.Write("garrycraft-collision-edits.json", util.TableToJSON(GC.CollisionEditTest.samples))
end
