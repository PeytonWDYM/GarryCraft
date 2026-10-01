local GC = GarryCraft

-- BSP traces stop slightly outside a plane. Read its collision triangle to avoid a fractional grid error.
local function exactFloor(hit)
    local vertices = game.GetWorld():GetPhysicsObject():GetMesh()
    local nearest, distance = hit.z, 2
    for index = 1, #vertices, 3 do
        local a, b, c = vertices[index].pos, vertices[index + 1].pos, vertices[index + 2].pos
        local bx, by, cx, cy = b.x - a.x, b.y - a.y, c.x - a.x, c.y - a.y
        local denominator = bx * cy - by * cx
        if math.abs(denominator) > .001 then
            local x, y = hit.x - a.x, hit.y - a.y
            local u, v = (x * cy - y * cx) / denominator, (bx * y - by * x) / denominator
            if u >= -.001 and v >= -.001 and u + v <= 1.001 then
                local height = a.z + u * (b.z - a.z) + v * (c.z - a.z)
                local delta = math.abs(height - hit.z)
                if delta < distance then nearest, distance = height, delta end
            end
        end
    end
    return nearest
end

-- Keep one stable vertical grid per map. The native spawn floor meets a Minecraft block boundary.
function GC.AlignGrid(player)
    local name = "garrycraft-grid-" .. game.GetMap() .. ".json"
    local saved = file.Read(name, "DATA")
    local height
    local previous = saved and util.JSONToTable(saved)
    if previous and previous.version == 2 then height = previous.height else
        local spawn = ents.FindByClass("info_player_start")[1] or player
        local position = spawn:GetPos()
        local ground = util.TraceLine({start = position + Vector(0, 0, 16),
            endpos = position - Vector(0, 0, 512), mask = MASK_SOLID_BRUSHONLY})
        local floor = ground.HitWorld and exactFloor(ground.HitPos) or 0
        height = floor - math.floor(floor / 32 + 0.5) * 32
        file.Write(name, util.TableToJSON({height = height, version = 2}))
    end
    GC.GridHeight = height
    player:SetNWFloat("GarryCraftGridHeight", height)
end
