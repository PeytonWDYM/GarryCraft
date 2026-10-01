local GC = GarryCraft
local cached
local cachedHeight

-- Read Source's BSP displacement records. Field layouts follow Valve's bspfile.h.
function GC.DisplacementGeometry()
    if cached and cachedHeight == GC.GridHeight then return cached end
    cachedHeight = GC.GridHeight
    local map = assert(file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME"), "Map BSP is unavailable")
    assert(map:Read(4) == "VBSP" and map:ReadLong() == 20, "Unsupported BSP format")
    local lumps = {}
    for index = 0, 63 do
        lumps[index] = {offset = map:ReadLong(), length = map:ReadLong(), version = map:ReadLong(), compressed = map:ReadLong()}
    end
    local function seek(lump, index, stride)
        local data = lumps[lump]
        assert(data.compressed == 0, "Compressed BSP geometry is not supported")
        assert(index >= 0 and (index + 1) * stride <= data.length, "BSP geometry index is out of bounds")
        assert(data.offset >= 0 and data.offset + data.length <= map:Size(), "BSP lump is out of bounds")
        map:Seek(data.offset + index * stride)
    end
    local function vector() return Vector(map:ReadFloat(), map:ReadFloat(), map:ReadFloat()) end
    local function append(output, a, b, c)
        local triangle = {}
        for _, point in ipairs({a, b, c}) do
            local position = GC.ToMinecraft(point)
            for axis = 1, 3 do triangle[#triangle + 1] = position[axis] end
        end
        output[#output + 1] = triangle
    end
    cached = {}
    for record = 0, lumps[26].length / 176 - 1 do
        seek(26, record, 176)
        local start = vector()
        local vertexStart, triangleStart, power, flags = map:ReadLong(), map:ReadLong(), map:ReadLong(), map:ReadLong()
        map:ReadFloat() -- smoothing angle
        local contents, faceIndex = map:ReadLong(), map:ReadUShort()
        local noHull = bit.band(flags, 0x80000000) ~= 0 and bit.band(flags, 4) ~= 0
        if bit.band(contents, CONTENTS_SOLID) ~= 0 and not noHull then
            assert(power >= 2 and power <= 4, "Unsupported displacement power")
            seek(7, faceIndex, 56)
            map:ReadLong() -- plane and side
            local firstEdge, edgeCount = map:ReadLong(), map:ReadShort()
            assert(edgeCount == 4, "Displacement base must be a quad")
            local corners = {}
            local closest, distance = 1, math.huge
            for edge = 0, 3 do
                seek(13, firstEdge + edge, 4)
                local signed = map:ReadLong()
                seek(12, math.abs(signed), 4)
                local first, second = map:ReadUShort(), map:ReadUShort()
                seek(3, signed >= 0 and first or second, 12)
                corners[edge + 1] = vector()
                local squared = corners[edge + 1]:DistToSqr(start)
                if squared < distance then closest, distance = edge + 1, squared end
            end
            local ordered = {}
            for index = 0, 3 do ordered[index + 1] = corners[(closest + index - 1) % 4 + 1] end
            local cells, points = 2 ^ power, {}
            local width = cells + 1
            for row = 0, cells do
                local left = LerpVector(row / cells, ordered[1], ordered[2])
                local right = LerpVector(row / cells, ordered[4], ordered[3])
                for column = 0, cells do
                    local index = row * width + column
                    seek(33, vertexStart + index, 20)
                    local direction, amount = vector(), map:ReadFloat()
                    points[index] = LerpVector(column / cells, left, right) + direction * amount
                end
            end
            local triangle = 0
            local function emit(a, b, c)
                seek(48, triangleStart + triangle, 2)
                local tags = map:ReadUShort()
                if bit.band(tags, 32) == 0 then append(cached, points[a], points[b], points[c]) end
                triangle = triangle + 1
            end
            for row = 0, cells - 1 do
                for column = 0, cells - 1 do
                    local index = row * width + column
                    if index % 2 == 1 then
                        emit(index, index + width, index + 1)
                        emit(index + 1, index + width, index + width + 1)
                    else
                        emit(index, index + width, index + width + 1)
                        emit(index, index + width + 1, index + 1)
                    end
                end
            end
        end
    end
    map:Close()
    print("GarryCraft: exported " .. #cached .. " displacement triangles")
    return cached
end

-- Compare real map geometry with the engine without moving either player.
function GC.CheckDisplacements()
    local report = {map = game.GetMap(), samples = {}, maximumError = 0, missed = 0, obstructed = 0,
        playArea = {samples = 0, maximumError = 0, missed = 0}}
    for index, triangle in ipairs(GC.DisplacementGeometry()) do
        if index % 8 == 0 then
            local a, b, c = GC.ToSource(unpack(triangle, 1, 3)), GC.ToSource(unpack(triangle, 4, 6)), GC.ToSource(unpack(triangle, 7, 9))
            local center = (a + b + c) / 3
            local normal = (b - a):Cross(c - a):GetNormalized()
            local trace = util.TraceLine({start = center + normal * 2, endpos = center - normal * 2, mask = MASK_PLAYERSOLID, filter = player.GetHumans()})
            if not trace.Hit or trace.StartSolid then
                trace = util.TraceLine({start = center - normal * 2, endpos = center + normal * 2, mask = MASK_PLAYERSOLID, filter = player.GetHumans()})
            end
            local obstructed = trace.StartSolid or trace.AllSolid
            local error = trace.Hit and trace.HitPos:Distance(center) or 4
            if obstructed then report.obstructed = report.obstructed + 1
            else
                report.maximumError = math.max(report.maximumError, error)
                if not trace.Hit then report.missed = report.missed + 1 end
                if math.abs(center.x) < 4000 and math.abs(center.y) < 6000 and math.abs(center.z) < 1000 then
                    report.playArea.samples = report.playArea.samples + 1
                    report.playArea.maximumError = math.max(report.playArea.maximumError, error)
                    if not trace.Hit then report.playArea.missed = report.playArea.missed + 1 end
                end
            end
            report.samples[#report.samples + 1] = {position = {center.x, center.y, center.z}, error = error, hit = trace.Hit, obstructed = obstructed}
        end
    end
    file.Write("garrycraft-terrain-check.json", util.TableToJSON(report))
end
