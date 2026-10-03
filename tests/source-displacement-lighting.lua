-- E2E gate for the displaced positions used by the native lightmap updater.
-- Failures: planar grass receivers, flipped normals, missing faces, or stale map data.
assert(game.SinglePlayer(), "Use an owned single-player lab")
GarryCraft.DisplacementLightingVerify = true
GarryCraft.StartDisplacementLighting()
timer.Create("GarryCraftDisplacementLightingGate", .25, 0, function()
    local report = GarryCraft.DisplacementLightingReport()
    if report.pending ~= 0 then return end
    timer.Remove("GarryCraftDisplacementLightingGate")
    GarryCraft.DisplacementLightingVerify = false
    local checks = {complete = report.registered == report.expected,
        sampled = report.playArea.samples > 20, geometry = report.playArea.maximumError < .5,
        hit = report.playArea.missed == 0, normals = report.flipped == 0}
    file.Write("garrycraft-displacement-lighting.json", util.TableToJSON({checks = checks, report = report}, true))
end)
