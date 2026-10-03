local GC = GarryCraft
local lights = {}
local revision = 0

function GC.SetBlockLights(sections)
    lights = {}
    for _, section in pairs(sections) do
        for _, light in ipairs(section.lights) do
            local position = GC.ToSource(light.x, light.y, light.z)
            local radius = light.emission * 32
            local color = Vector(bit.band(bit.rshift(light.color, 16), 255),
                bit.band(bit.rshift(light.color, 8), 255), bit.band(light.color, 255))
            lights[#lights + 1] = {position = position, radius = radius, emission = light.emission, color = color / 255,
                model = {type = MATERIAL_LIGHT_POINT, pos = position, color = color * (.2 * light.emission / (255 * 15)),
                    fiftyPercentDistance = radius * .35, zeroPercentDistance = radius}}
        end
    end
    revision = garrycraft_bridge.voxel_lighting_report().revision + garrycraft_bridge.lighting_report().revision
end
local function visible(light, position)
    if util.TraceLine({start = position, endpos = light.position, mask = MASK_SOLID_BRUSHONLY}).Hit then return 0 end
    return garrycraft_bridge.light_transmission(position, light.position, GC.GridHeight)
end

-- Native dynamic lights remain engine-owned. Minecraft never allocates an unoccluded DynamicLight.
function GC.SourceDynamicLighting(position, normals)
    local colors = {}
    for index, normal in ipairs(normals) do colors[index] = render.ComputeDynamicLighting(position, normal) end
    return colors
end
local function receiverLights(position)
    local nearest = {}
    for _, light in ipairs(lights) do
        local distance = position:DistToSqr(light.position)
        local transmission = distance < light.radius * light.radius and (not nearest[4] or distance < nearest[4].distance)
            and visible(light, position) or 0
        if transmission > 0 then
            local index = 1
            while nearest[index] and nearest[index].distance <= distance do index = index + 1 end
            if index <= 4 then
                table.insert(nearest, index, {distance = distance, light = light, transmission = transmission})
                nearest[5] = nil
            end
        end
    end
    return nearest
end
function GC.ModelLights(position)
    local result = {}
    for index, entry in ipairs(receiverLights(position)) do
        result[index] = table.Copy(entry.light.model)
        result[index].color = result[index].color * entry.transmission
    end
    return result, revision
end

-- Read the propagated field rather than summing a camera-selected dynamic-light budget.
function GC.VisibleBlockLight(position)
    local voxel = GC.VoxelLight(position)
    return voxel and Vector(1, .87, .67) * voxel.blockBrightnessInterpolated or Vector()
end
function GC.LightRevision() return revision end
function GC.BlockLightSources() return lights end
function GC.LightReport()
    return {exported = #lights, selected = 0, allocated = 0, worldLimit = 0, mode = "visible-receivers",
        occlusion = garrycraft_bridge.lighting_report(), voxels = GC.VoxelLightingReport()}
end
