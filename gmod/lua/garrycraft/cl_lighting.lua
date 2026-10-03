local GC = GarryCraft
local normals = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1)}
local view = {colors = {}}

-- IMesh inherits model lighting. Set every ambient direction explicitly before each draw pass.
function GC.PrepareLighting(position, sample)
    sample = sample or view
    local now = RealTime()
    local refresh = not sample.position or now >= sample.time or position:DistToSqr(sample.position) > 16
        or sample.geometryRevision ~= GC.LightRevision()
        or sample.sunRevision ~= GC.SunRevision()
    if refresh then
        sample.position, sample.time = position, now + .25
        sample.geometryRevision = GC.LightRevision()
        sample.sunRevision = GC.SunRevision()
        local voxel = GC.VoxelLight(position)
        local ambient = voxel and voxel.skyBrightnessInterpolated or 1
        local block = voxel and Vector(1, .87, .67) * voxel.blockBrightnessInterpolated or Vector()
        for index, normal in ipairs(normals) do
            local color = render.ComputeLighting(position, normal) - render.ComputeDynamicLighting(position, normal)
            sample.colors[index] = color * garrycraft_bridge.source_sky_factor(position, normal, ambient) + block
        end
        local sourceDynamic = GC.SourceDynamicLighting(position, normals)
        for index, color in ipairs(sample.colors) do
            color = color + sourceDynamic[index]
            -- Native lamps remain separate from Minecraft's propagated sky and block irradiance.
            sample.colors[index] = Vector(math.max(0, color.x), math.max(0, color.y), math.max(0, color.z))
        end
    end
    render.SetLightingOrigin(position)
    render.SetLocalModelLights({})
    for index, color in ipairs(sample.colors) do render.SetModelLighting(index - 1, color.x, color.y, color.z) end
end

-- Do not leave Minecraft's ambient cube or local lights on subsequent Source draws.
function GC.RestoreLighting()
    render.SetLocalModelLights({})
    render.SetLightingOrigin(EyePos())
    render.ResetModelLighting(1, 1, 1)
end

function GC.LightingExposure(position)
    local total = 0
    for _, value in ipairs(garrycraft_bridge.light_exposure(position)) do total = total + value end
    return total / 6
end
