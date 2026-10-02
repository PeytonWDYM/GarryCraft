local GC = GarryCraft
local models = {}

-- Load each model's real physics mesh once. The temporary entity never enters the game world.
local function modelMesh(name, solid)
    local key = name .. ":" .. solid
    if models[key] then return models[key] end
    local entity = ents.Create("prop_physics")
    entity.GarryCraftMirror = true
    entity:SetModel(name)
    local mesh
    if solid == SOLID_VPHYSICS and entity:PhysicsInit(SOLID_VPHYSICS) then
        mesh = entity:GetPhysicsObject():GetMesh()
    elseif solid == SOLID_BBOX then
        local lo, hi = entity:GetModelBounds()
        local points = {Vector(lo.x,lo.y,lo.z),Vector(lo.x,lo.y,hi.z),Vector(lo.x,hi.y,lo.z),Vector(lo.x,hi.y,hi.z),
            Vector(hi.x,lo.y,lo.z),Vector(hi.x,lo.y,hi.z),Vector(hi.x,hi.y,lo.z),Vector(hi.x,hi.y,hi.z)}
        mesh = {}
        for _, face in ipairs({{1,3,4,2},{5,6,8,7},{1,2,6,5},{3,7,8,4},{1,5,7,3},{2,4,8,6}}) do
            for _, index in ipairs({1,2,3,1,3,4}) do mesh[#mesh+1] = {pos=points[face[index]]} end
        end
    end
    entity:Remove()
    models[key] = mesh or {}
    return models[key]
end

-- Valve's static-prop game lump stores collision mode, model, origin, and angles outside ents.GetAll().
function GC.StaticPropGeometry()
    local map = assert(file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME"), "Map BSP is unavailable")
    assert(map:Read(4) == "VBSP" and map:ReadLong() == 20, "Unsupported BSP format")
    map:Seek(8 + 35 * 16)
    local offset, length = map:ReadLong(), map:ReadLong()
    if length == 0 then map:Close() return {} end
    map:Seek(offset)
    local count = map:ReadLong()
    local lump
    for index = 1, count do
        local id, flags, version = map:ReadLong(), map:ReadUShort(), map:ReadUShort()
        local start, size = map:ReadLong(), map:ReadLong()
        if id == 1936749168 then lump = {offset=start,length=size,version=version,flags=flags} end
    end
    if not lump then map:Close() return {} end
    assert(lump.flags == 0 and lump.version >= 4 and lump.version <= 11, "Unsupported static-prop BSP format")
    assert(lump.offset >= 0 and lump.offset + lump.length <= map:Size(), "Static-prop lump is out of bounds")
    map:Seek(lump.offset)
    local names = {}
    local modelCount = map:ReadLong()
    assert(modelCount >= 0 and modelCount * 128 + 4 <= lump.length, "Static-prop model dictionary is out of bounds")
    for index = 1, modelCount do names[index] = string.match(map:Read(128), "^[^%z]*") end
    local leaves = map:ReadLong()
    assert(leaves >= 0 and map:Tell() + leaves * 2 + 4 <= lump.offset + lump.length, "Static-prop leaves are out of bounds")
    map:Skip(leaves * 2)
    local propCount = map:ReadLong()
    if propCount == 0 then map:Close() return {} end
    local stride = (lump.offset + lump.length - map:Tell()) / propCount
    assert(propCount > 0 and stride >= 56 and stride <= 84 and stride == math.floor(stride), "Unsupported static-prop record size")
    local triangles, solidCount, missing, missingModels = {}, 0, 0, {}
    local function vector() return Vector(map:ReadFloat(), map:ReadFloat(), map:ReadFloat()) end
    for index = 1, propCount do
        local start = map:Tell()
        local origin = vector()
        local angles = Angle(map:ReadFloat(), map:ReadFloat(), map:ReadFloat())
        local name = assert(names[map:ReadUShort()+1], "Static-prop model index is out of bounds")
        map:Skip(4)
        local solid = map:ReadByte()
        local scale = 1
        if lump.version == 11 then map:Seek(start + stride - 4) scale = map:ReadFloat() end
        if solid == SOLID_VPHYSICS or solid == SOLID_BBOX then
            solidCount = solidCount + 1
            local mesh = modelMesh(name, solid)
            if #mesh == 0 then missing = missing + 1 missingModels[name] = true end
            for first = 1, #mesh, 3 do
                local triangle = {}
                for vertex = first, first + 2 do
                    local point = LocalToWorld(mesh[vertex].pos * scale, angle_zero, origin, angles)
                    local coordinates = GC.ToMinecraft(point)
                    for axis = 1, 3 do triangle[#triangle+1] = coordinates[axis] end
                end
                triangles[#triangles+1] = triangle
            end
        end
        map:Seek(start + stride)
    end
    map:Close()
    GC.StaticPropReport = {props=propCount,solid=solidCount,missing=missing,missingModels=table.GetKeys(missingModels),
        triangles=#triangles,version=lump.version}
    print("GarryCraft static props: " .. util.TableToJSON(GC.StaticPropReport))
    return triangles
end
