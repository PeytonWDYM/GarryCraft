local GC = GarryCraft
local physicsMeshes = setmetatable({}, {__mode = "k"})

local function physicsMesh(physics)
    local mesh = physicsMeshes[physics]
    if not mesh then mesh = physics:GetMesh() physicsMeshes[physics] = mesh end
    return mesh
end

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
    for _, triangle in ipairs(GC.StaticPropGeometry()) do triangles[#triangles + 1] = triangle end
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
    local point = player:GetPos()
    for _, entity in ipairs(ents.FindInBox(point - Vector(512, 512, 512), point + Vector(512, 512, 512))) do
        if entity ~= player and not entity.GarryCraftMirror and entity ~= game.GetWorld() and entity:GetClass() ~= "gc_block"
            and entity:IsSolid() and bit.band(entity:GetSolidFlags(), FSOLID_TRIGGER) == 0
            and not excludedGroups[entity:GetCollisionGroup()]
            and not entity:GetNWBool("GarryCraftStatic") then
            local found = entity:IsNPC() or entity:GetSolid() == SOLID_BBOX
            if found then appendBounds(triangles, entity) end
            for index = 0, (found and 0 or entity:GetPhysicsObjectCount()) - 1 do
                local physics = entity:GetPhysicsObjectNum(index)
                if IsValid(physics) and physics:IsCollisionEnabled() then
                    local mesh = physicsMesh(physics)
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

local shapeCache = {}
local geometryStats = {}
local geometryPeer = {}
local geometryTrace = false
local range = Vector(512, 512, 512)

function GC.MovingGeometryStats() return geometryStats end
function GC.MovingGeometryPeer() return geometryPeer end
function GC.MovingGeometryTrace(enabled) geometryTrace = enabled end

function GC.GeometryBegin()
    shapeCache = {}
    geometryStats = {}
    geometryPeer = {}
    geometryTrace = false
    garrycraft_bridge.geometry_clear()
end

function GC.GeometryPeer(state) geometryPeer = state.movingGeometry or {} end

-- Keep only bodies in the complete current snapshot. Range exit and removal retire their shapes.
function GC.DynamicGeometryPacket(player, session, acknowledged)
    local started = SysTime()
    local instances, nextCache = {}, {}
    local meshReads = 0
    local function instance(entity, part, physics, bounds)
        local minimum, maximum = entity:GetCollisionBounds()
        local key = entity:EntIndex() .. ":" .. entity:GetCreationID() .. ":" .. part
        local previous = shapeCache[key]
        local model, scale = entity:GetModel(), entity:GetModelScale()
        local cached = previous and previous.physics == physics and previous.model == model
            and previous.scale == scale and previous.minimum == minimum and previous.maximum == maximum
        local shape = cached and previous.shape
        if not shape then
            if bounds then shape = garrycraft_bridge.geometry_box(minimum, maximum)
            else
                local mesh = physics:GetMesh()
                meshReads = meshReads + 1
                if not mesh then return false end
                shape = garrycraft_bridge.geometry_mesh(mesh)
            end
            previous = {physics = physics, model = model, scale = scale, minimum = minimum, maximum = maximum, shape = shape}
        end
        nextCache[key] = previous
        local position = bounds and entity:GetPos() or physics:GetPos()
        local angles = bounds and (entity:GetSolid() == SOLID_BBOX and angle_zero or entity:GetAngles()) or physics:GetAngles()
        instances[#instances + 1] = {entity:EntIndex(), entity:GetCreationID(), part, shape, position, angles}
        return true
    end
    local point = player:GetPos()
    local queryStarted = SysTime()
    local candidates = ents.FindInBox(point - range, point + range)
    local queryFinished = SysTime()
    for _, entity in ipairs(candidates) do
        if entity ~= player and not entity.GarryCraftMirror and entity ~= game.GetWorld() and entity:GetClass() ~= "gc_block"
            and entity:IsSolid() and bit.band(entity:GetSolidFlags(), FSOLID_TRIGGER) == 0
            and not excludedGroups[entity:GetCollisionGroup()] and not entity:GetNWBool("GarryCraftStatic") then
            local found = entity:IsNPC() or entity:GetSolid() == SOLID_BBOX
            if found then instance(entity, -1, nil, true) end
            for index = 0, (found and 0 or entity:GetPhysicsObjectCount()) - 1 do
                local physics = entity:GetPhysicsObjectNum(index)
                if IsValid(physics) and physics:IsCollisionEnabled() then
                    if instance(entity, index, physics, false) then found = true end
                end
            end
            if not found and (entity:GetSolid() == SOLID_BBOX or entity:GetSolid() == SOLID_OBB) then
                instance(entity, -1, nil, true)
            end
        end
    end
    shapeCache = nextCache
    local instancesFinished = SysTime()
    local water = GC.WaterGrid(player)
    local waterFinished = SysTime()
    local actors = GC.EntityTargets(player)
    local actorsFinished = SysTime()
    local header = util.TableToJSON({session = session, movingGeometry = 2, gridHeight = GC.GridHeight,
        geometryTrace = geometryTrace, water = water})
    local jsonFinished = SysTime()
    local payload, triangles, pending = garrycraft_bridge.geometry_packet(header, instances, acknowledged, actors)
    local packed = SysTime()
    geometryStats = {milliseconds = (packed - started) * 1000, bytes = #payload, candidates = #candidates,
        queryMilliseconds = (queryFinished - queryStarted) * 1000,
        instancesMilliseconds = (instancesFinished - queryFinished) * 1000,
        waterMilliseconds = (waterFinished - instancesFinished) * 1000,
        actorsMilliseconds = (actorsFinished - waterFinished) * 1000,
        jsonMilliseconds = (jsonFinished - actorsFinished) * 1000,
        packMilliseconds = (packed - jsonFinished) * 1000, headerBytes = #header, actorCount = #actors,
        instances = #instances, triangles = triangles, meshReads = meshReads, pendingShapes = pending}
    return payload
end
