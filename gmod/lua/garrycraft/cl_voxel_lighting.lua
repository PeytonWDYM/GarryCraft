local GC = GarryCraft
local session, instance, height

hook.Add("Think", "GarryCraftNativeVoxelLighting", function()
    if GC.VideoReset or not GC.State or not GC.State.linked or not IsValid(LocalPlayer())
        or not LocalPlayer():GetNWBool("GarryCraft") then
        if session then
            GC.StopDisplacementLighting()
            garrycraft_bridge.source_lightmaps_stop()
            garrycraft_bridge.source_model_lighting_stop()
        end
        session, instance, height = nil, nil, nil
        return
    end
    if session ~= GC.State.session or instance ~= GC.State.renderInstance or height ~= GC.GridHeight then
        garrycraft_bridge.source_model_lighting_stop()
        garrycraft_bridge.source_lightmaps_stop()
        garrycraft_bridge.source_model_lighting_start(GC.GridHeight)
        assert(garrycraft_bridge.source_lightmaps_start(GC.GridHeight))
        render.RedownloadAllLightmaps()
        GC.StartDisplacementLighting()
        session, instance, height = GC.State.session, GC.State.renderInstance, GC.GridHeight
    end
    garrycraft_bridge.source_lightmaps_update()
end)

-- Minecraft owns propagation and material absorption. Source consumes the resulting irradiance.
function GC.VoxelLight(position)
    return garrycraft_bridge.sample_voxel_lighting(position, GC.GridHeight)
end

function GC.VoxelLightingReport()
    local report = garrycraft_bridge.voxel_lighting_report()
    report.models = garrycraft_bridge.source_model_lighting_report()
    report.lightmaps = garrycraft_bridge.source_lightmaps_report()
    report.displacements = GC.DisplacementLightingReport()
    return report
end

hook.Add("ShutDown", "GarryCraftNativeVoxelLightingCleanup", function()
    garrycraft_bridge.source_model_lighting_stop()
    GC.StopDisplacementLighting()
    garrycraft_bridge.source_lightmaps_stop()
end)
