-- Run on an owned map with no displacements. Check the fixture before starting the production callback.
assert(game.SinglePlayer(), "Use an owned single-player lab")
local bsp = assert(file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME"))
bsp:Seek(8 + 26 * 16 + 4)
local displacementBytes = bsp:ReadLong()
bsp:Close()
assert(displacementBytes == 0, "The fixture must contain no displacements")
GarryCraft.StartDisplacementLighting()
local report = GarryCraft.DisplacementLightingReport()
assert(report.expected == 0, "The fixture must contain no displacements")
local callback = hook.GetTable().Think.GarryCraftDisplacementLightmaps
local firstFrame, firstError = pcall(callback)
timer.Simple(2, function()
    local idleFrame, idleError = pcall(callback)
    local current = GarryCraft.DisplacementLightingReport()
    local checks = {empty = current.expected == 0, idle = current.pending == 0,
        nothingUploaded = current.registered == 0, noBuild = current.maxBuildMs == 0,
        firstFrame = firstFrame, idleFrame = idleFrame}
    file.Write("garrycraft-empty-displacements.json", util.TableToJSON({map = game.GetMap(), checks = checks, report = current,
        firstError = firstError, idleError = idleError}, true))
end)
