local GC = GarryCraft
local normals = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1)}
local view = {colors = {}}

-- IMesh inherits model lighting. Set every ambient direction explicitly before each draw pass.
function GC.PrepareLighting(position, sample)
    sample = sample or view
    local now = RealTime()
    if not sample.position or now >= sample.time or position:DistToSqr(sample.position) > 16 then
        sample.position, sample.time = position, now + .25
        for index, normal in ipairs(normals) do
            sample.colors[index] = render.ComputeLighting(position, normal) - render.ComputeDynamicLighting(position, normal)
        end
    end
    if sample.revision ~= GC.LightRevision() or sample.lightsPosition ~= position then
        sample.lights, sample.revision = GC.ModelLights(position)
        sample.lightsPosition = position
    end
    render.SetLightingOrigin(position)
    render.SetLocalModelLights(sample.lights)
    for index, color in ipairs(sample.colors) do render.SetModelLighting(index - 1, color.x, color.y, color.z) end
end
