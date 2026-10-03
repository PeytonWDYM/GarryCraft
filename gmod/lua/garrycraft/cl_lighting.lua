local GC = GarryCraft
local normals = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1)}
local view = {colors = {}}

-- IMesh inherits model lighting. Set every ambient direction explicitly before each draw pass.
function GC.PrepareLighting(position, sample)
    sample = sample or view
    local now = RealTime()
    local refresh = not sample.position or now >= sample.time or position:DistToSqr(sample.position) > 16
        or sample.geometryRevision ~= GC.LightRevision()
    if refresh then
        sample.position, sample.time = position, now + .25
        sample.geometryRevision = GC.LightRevision()
        for index, normal in ipairs(normals) do
            local color = render.ComputeLighting(position, normal) - render.ComputeDynamicLighting(position, normal)
            sample.colors[index] = color
        end
        local sourceDynamic = GC.SourceDynamicLighting(position, normals)
        for index, color in ipairs(sample.colors) do
            color = color + sourceDynamic[index]
            -- Preserve Source ambient and native lamps; Minecraft torches are added once through visible local lights.
            sample.colors[index] = Vector(math.max(0, color.x), math.max(0, color.y), math.max(0, color.z))
        end
    end
    -- Native brush movement does not change the Minecraft section revision. Reuse the ambient cache's bounded refresh.
    if refresh or sample.revision ~= GC.LightRevision() or not sample.lightsPosition or position:DistToSqr(sample.lightsPosition) > 16 then
        sample.lights, sample.revision = GC.ModelLights(position)
        sample.lightsPosition = position
    end
    render.SetLightingOrigin(position)
    render.SetLocalModelLights(sample.lights)
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
