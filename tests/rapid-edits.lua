-- Owned single-player fixture. Failures: lost placement, stale neighboring faces,
-- or a section mesh that still disagrees with its occupied cells after input stops.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
GC.RapidEditTest = {}
function GC.RapidEditTest.Begin(x, y, z)
    local origin = Vector(x, y, z)
    local previousControls = GC.TestClientControls
    local previousCamera = hook.GetTable().CalcView.GarryCraftCamera
    local started, nextSample = RealTime(), 0
    local run = {origin = {x,y,z}, frames = {}, input = "Minecraft placement and creative mining through lane 8"}
    local target = GC.ToSource(x + 1.5, y + 1, z + 1.5)
    GC.TestClientControls = function(controls)
        local eye = GC.ToSource(GC.State.x, GC.State.y + GC.State.eye, GC.State.z)
        local look = (target - eye):Angle()
        controls.yaw, controls.pitch, controls.slot = -look.y - 90, look.p, 1
        local elapsed = RealTime() - started
        local part = elapsed % .4
        controls.use = elapsed < 24 and part < .075
        controls.attack = elapsed < 24 and part >= .2 and part < .275
    end
    hook.Add("CalcView", "GarryCraftCamera", function()
        GC.ViewOrigin, GC.ViewAngles = GC.ToSource(x + 2, y + 3, z + 5), Angle(30, 90, 0)
        return {origin = GC.ViewOrigin, angles = GC.ViewAngles, fov = 75}
    end)
    local function stop()
        GC.TestClientControls = previousControls
        hook.Add("CalcView", "GarryCraftCamera", previousCamera)
        hook.Remove("PostRender", "GarryCraftRapidEditTest")
    end
    GC.RapidEditTest.Stop = stop
    hook.Add("PostRender", "GarryCraftRapidEditTest", function()
        local elapsed = RealTime() - started
        if elapsed < nextSample then return end
        nextSample = elapsed + .1
        local occupied, count = {}, 0
        local function key(dx,dy,dz) return dx .. "," .. dy .. "," .. dz end
        for dx = -2, 4 do for dy = -2, 4 do for dz = -2, 4 do
            local voxel = GC.VoxelLight(GC.ToSource(x + dx + .5, y + dy + .5, z + dz + .5))
            if voxel and voxel.opaque then occupied[key(dx,dy,dz)] = true count = count + 1 end
        end end end
        local faces = 0
        for dx = -1, 3 do for dy = -1, 3 do for dz = -1, 3 do
            if occupied[key(dx,dy,dz)] then
                for _, direction in ipairs({Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0),Vector(0,0,1),Vector(0,0,-1)}) do
                    if not occupied[key(dx+direction.x,dy+direction.y,dz+direction.z)] then faces = faces + 1 end
                end
            end
        end end end
        local report = GC.BlockRenderReport()
        run.frames[#run.frames + 1] = {time = elapsed, cells = count, expectedFaces = faces,
            vertices = report.vertices, ack = report.ack, rebuilt = report.rebuilt, reused = report.reused}
        if elapsed >= 27 then
            file.Write("garrycraft-rapid-edits.json", util.TableToJSON(run, true))
            file.Write("garrycraft-rapid-edits.png", render.Capture({format="png",x=0,y=0,w=ScrW(),h=ScrH(),alpha=false}))
            stop()
        end
    end)
end
