local GC = GarryCraft

local function appendMesh(output, mesh, transform, sourceEntity)
    for index = 1, #mesh, 3 do
        local triangle = {}
        for vertex = index, index + 2 do
            local point = mesh[vertex].pos
            if transform then point = transform:LocalToWorld(point) end
            local coordinates = GC.ToMinecraft(point)
            triangle[#triangle + 1] = coordinates[1]
            triangle[#triangle + 1] = coordinates[2]
            triangle[#triangle + 1] = coordinates[3]
        end
        if sourceEntity then triangle[10] = sourceEntity end
        output[#output + 1] = triangle
    end
end

function GC.StaticGeometry()
    local world = game.GetWorld()
    local physics = world:GetPhysicsObject()
    local triangles = {}
    if IsValid(physics) then
        local mesh = physics:GetMesh()
        if mesh then appendMesh(triangles, mesh) end
    end
    for _, triangle in ipairs(GC.DisplacementGeometry()) do triangles[#triangles + 1] = triangle end
    for _, entity in ipairs(ents.GetAll()) do
        if entity:GetNWBool("GarryCraftStatic") then
            local physics = entity:GetPhysicsObject()
            appendMesh(triangles, physics:GetMesh(), physics)
        end
    end
    assert(#triangles > 0, "GarryCraft could not read this map's collision mesh")
    local batches = {}
    for first = 1, #triangles, 1000 do
        local batch = {}
        for index = first, math.min(first + 999, #triangles) do batch[#batch + 1] = triangles[index] end
        batches[#batches + 1] = batch
    end
    print("GarryCraft: exported " .. #triangles .. " map collision triangles")
    return batches
end

local function appendBounds(output, entity)
    local minimum, maximum = entity:GetCollisionBounds()
    local corners = {}
    for _, x in ipairs({minimum.x, maximum.x}) do
        for _, y in ipairs({minimum.y, maximum.y}) do
            for _, z in ipairs({minimum.z, maximum.z}) do
                local point = Vector(x, y, z)
                point = entity:GetSolid() == SOLID_BBOX and point + entity:GetPos() or entity:LocalToWorld(point)
                corners[#corners + 1] = GC.ToMinecraft(point)
            end
        end
    end
    for _, face in ipairs({{1, 3, 4, 2}, {5, 6, 8, 7}, {1, 2, 6, 5}, {3, 7, 8, 4}, {1, 5, 7, 3}, {2, 4, 8, 6}}) do
        for _, order in ipairs({{1, 2, 3}, {1, 3, 4}}) do
            local triangle = {}
            for _, index in ipairs(order) do
                for _, coordinate in ipairs(corners[face[index]]) do triangle[#triangle + 1] = coordinate end
            end
            triangle[10] = entity:EntIndex()
            output[#output + 1] = triangle
        end
    end
end

local excludedGroups = {[COLLISION_GROUP_DEBRIS] = true, [COLLISION_GROUP_DEBRIS_TRIGGER] = true,
    [COLLISION_GROUP_WEAPON] = true, [COLLISION_GROUP_IN_VEHICLE] = true}

function GC.DynamicGeometry(player)
    local triangles = {}
    for _, entity in ipairs(ents.GetAll()) do
        local minimum, maximum = entity:WorldSpaceAABB()
        local point = player:GetPos()
        local nearby = minimum.x <= point.x + 512 and maximum.x >= point.x - 512
            and minimum.y <= point.y + 512 and maximum.y >= point.y - 512
            and minimum.z <= point.z + 512 and maximum.z >= point.z - 512
        if nearby and entity ~= player and not entity.GarryCraftMirror and entity ~= game.GetWorld() and entity:GetClass() ~= "gc_block"
            and entity:IsSolid() and bit.band(entity:GetSolidFlags(), FSOLID_TRIGGER) == 0
            and not excludedGroups[entity:GetCollisionGroup()]
            and not entity:GetNWBool("GarryCraftStatic") then
            local found = entity:IsNPC() or entity:GetSolid() == SOLID_BBOX
            if found then appendBounds(triangles, entity) end
            for index = 0, (found and 0 or entity:GetPhysicsObjectCount()) - 1 do
                local physics = entity:GetPhysicsObjectNum(index)
                if IsValid(physics) and physics:IsCollisionEnabled() then
                    local mesh = physics:GetMesh()
                    if mesh then appendMesh(triangles, mesh, physics, entity:EntIndex()) found = true end
                end
            end
            if not found and (entity:GetSolid() == SOLID_BBOX or entity:GetSolid() == SOLID_OBB) then
                appendBounds(triangles, entity)
            end
        end
    end
    return triangles
end
