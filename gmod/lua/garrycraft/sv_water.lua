local GC = GarryCraft
local cache

function GC.WaterSurface(x, y)
    local minimum, maximum = game.GetWorld():GetModelBounds()
    local water = util.TraceLine({start = Vector(x, y, maximum.z + 32),
        endpos = Vector(x, y, minimum.z - 32), mask = CONTENTS_WATER})
    local submerged = bit.band(util.PointContents(water.HitPos - Vector(0, 0, 1)), CONTENTS_WATER) ~= 0
    return water.Hit and submerged and (water.HitPos.z - GC.GridHeight) / 32 or -1e30
end

-- Source supplies its real water surface. Minecraft handles swimming and drowning.
function GC.WaterGrid(player)
    local position = GC.ToMinecraft(player:GetPos())
    local x, z = math.floor(position[1]) - 4, math.floor(position[3]) - 4
    if cache and cache.originX == x and cache.originZ == z and cache.gridHeight == GC.GridHeight then return cache end
    local surface = {}
    for dz = 0, 8 do
        for dx = 0, 8 do
            local point = GC.ToSource(x + dx + 0.5, position[2], z + dz + 0.5)
            -- Start above all water brushes, including when the player is already submerged.
            surface[#surface + 1] = GC.WaterSurface(point.x, point.y)
        end
    end
    cache = {originX = x, originZ = z, size = 9, surface = surface, gridHeight = GC.GridHeight}
    return cache
end
