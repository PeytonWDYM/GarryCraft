local GC = GarryCraft
local lights, active = {}, {}
local nextSelection = 0
local revision = 0
local allocated = 0

function GC.SetBlockLights(sections)
    lights = {}
    for _, section in pairs(sections) do
        for _, light in ipairs(section.lights) do
            local position = GC.ToSource(light.x, light.y, light.z)
            local radius = light.emission * 32
            local color = Vector(bit.band(bit.rshift(light.color, 16), 255),
                bit.band(bit.rshift(light.color, 8), 255), bit.band(light.color, 255))
            lights[#lights + 1] = {position = position, radius = radius, color = color, emission = light.emission,
                id = tonumber(util.CRC("garrycraft/light/" .. tostring(position))),
                model = {type = MATERIAL_LIGHT_POINT, pos = position, color = color * (.2 * light.emission / (255 * 15)),
                    fiftyPercentDistance = radius * .35, zeroPercentDistance = radius}}
        end
    end
    nextSelection = 0
    revision = revision + 1
end

-- Reserve half of Source's 32 world lights. Nearby emitters retain priority over distant fluid cells.
hook.Add("PreRender", "GarryCraftBlockLights", function()
    if GC.VideoReset or not GC.State or not GC.State.linked or not IsValid(LocalPlayer())
            or not LocalPlayer():GetNWBool("GarryCraft") then return end
    if RealTime() >= nextSelection then
        nextSelection = RealTime() + .1
        local eye = EyePos()
        for _, light in ipairs(lights) do light.distance = eye:DistToSqr(light.position) / (light.radius * light.radius) end
        table.sort(lights, function(a, b) return a.distance == b.distance and a.id < b.id or a.distance < b.distance end)
        active = {}
        for index = 1, math.min(16, #lights) do active[index] = lights[index] end
    end
    allocated = 0
    for _, light in ipairs(active) do
        local source = DynamicLight(light.id)
        if source then
            source.pos = light.position
            source.r, source.g, source.b = light.color.x, light.color.y, light.color.z
            source.brightness, source.size = 2 * light.emission / 15, light.radius
            source.decay, source.style, source.noworld, source.nomodel = 0, 0, false, false
            source.dietime = CurTime() + .2
            allocated = allocated + 1
        end
    end
end)

function GC.ModelLights(position)
    local nearest = {}
    -- Local mesh lights use every exported emitter. The world-light budget cannot remove room lighting.
    for _, light in ipairs(lights) do
        local distance = position:DistToSqr(light.position)
        if distance < light.radius * light.radius and not garrycraft_bridge.light_occluded(position, light.position)
                and not util.TraceLine({start = position, endpos = light.position, mask = MASK_SOLID_BRUSHONLY}).Hit then
            local index = 1
            while nearest[index] and nearest[index].distance <= distance do index = index + 1 end
            if index <= 4 then
                table.insert(nearest, index, {distance = distance, light = light.model})
                nearest[5] = nil
            end
        end
    end
    local result = {}
    for index, entry in ipairs(nearest) do result[index] = entry.light end
    return result, revision
end

function GC.LightRevision() return revision end
function GC.LightReport() return {exported = #lights, selected = #active, allocated = allocated, worldLimit = 16,
    occlusion = garrycraft_bridge.lighting_report()} end
