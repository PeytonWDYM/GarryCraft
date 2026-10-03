-- Run through tools/Test-Architecture.ps1 in a fresh linked single-player lab world.
-- Failure cases: a dirty section leaves the export radius, its last block disappears,
-- the player returns, and Source retains stale collision. A video reset with an open
-- Minecraft menu must also recover the scene and HUD without ending the session.
local GC = GarryCraft
assert(game.SinglePlayer() and GC.IsLinked(), "Architecture tests require a linked single-player lab session")
GC.ArchitectureTest = {}
function GC.ArchitectureTest.Snapshot(name, x, y, z)
    local center = GC.ToSource(x + .5, y + .5, z + .5)
    local trace = util.TraceLine({start = center - Vector(24, 0, 0), endpos = center + Vector(24, 0, 0), mask = MASK_SOLID})
    file.Write("garrycraft-architecture-" .. name .. ".json", util.TableToJSON({phase = name,
        block = {x, y, z}, hostCollision = IsValid(trace.Entity) and trace.Entity:GetClass() == "gc_block",
        linked = GC.IsLinked(), active = GC.IsActive()}, true))
end
