local GC = GarryCraft
local mapFile, lumps, queue, index
local current, bytes, pixel
local report = {pending = 0, expected = 0, registered = 0, flipped = 0,
    playArea = {samples = 0, maximumError = 0, missed = 0}}

local function seek(lump, record, stride)
    local data = lumps[lump]
    assert(data.compressed == 0, "Compressed displacement lightmaps are not supported")
    assert(record >= 0 and (record + 1) * stride <= data.length, "Displacement record is out of bounds")
    assert(data.offset >= 0 and data.offset + data.length <= mapFile:Size(), "BSP lump is out of bounds")
    mapFile:Seek(data.offset + record * stride)
end

local function vector() return Vector(mapFile:ReadFloat(), mapFile:ReadFloat(), mapFile:ReadFloat()) end
local function coordinates(axis, offset, point) return axis:Dot(point) + offset end

local function readFace(record)
    seek(26, record, 176)
    local start = vector()
    local vertexStart = mapFile:ReadLong()
    mapFile:ReadLong() -- Triangle start
    local power = mapFile:ReadLong()
    mapFile:ReadLong() -- Flags
    mapFile:ReadFloat() -- Smoothing
    mapFile:ReadLong() -- Contents
    local handle = mapFile:ReadUShort()
    assert(power >= 2 and power <= 4, "Unsupported displacement power")
    seek(7, handle, 56)
    local plane, side = mapFile:ReadUShort(), mapFile:ReadByte()
    mapFile:ReadByte() -- Node flag
    local firstEdge, edges, texinfo = mapFile:ReadLong(), mapFile:ReadUShort(), mapFile:ReadShort()
    assert(edges == 4, "Displacement lightmap must have a quad base")
    mapFile:Seek(lumps[7].offset + handle * 56 + 28)
    local minS, minT = mapFile:ReadLong(), mapFile:ReadLong()
    local width, height = mapFile:ReadLong() + 1, mapFile:ReadLong() + 1
    seek(1, plane, 20)
    local normal = vector() * (side == 0 and 1 or -1)
    seek(6, texinfo, 72)
    mapFile:Seek(lumps[6].offset + texinfo * 72 + 32)
    local axisS, offsetS = vector(), mapFile:ReadFloat()
    local axisT, offsetT = vector(), mapFile:ReadFloat()
    local corners, closest, distance = {}, 1, math.huge
    for edge = 0, 3 do
        seek(13, firstEdge + edge, 4)
        local signed = mapFile:ReadLong()
        seek(12, math.abs(signed), 4)
        local first, second = mapFile:ReadUShort(), mapFile:ReadUShort()
        seek(3, signed >= 0 and first or second, 12)
        corners[edge + 1] = vector()
        local squared = corners[edge + 1]:DistToSqr(start)
        if squared < distance then closest, distance = edge + 1, squared end
    end
    local ordered, uv = {}, {}
    for corner = 0, 3 do
        local point = corners[(closest + corner - 1) % 4 + 1]
        ordered[corner + 1] = point
        uv[corner + 1] = Vector(coordinates(axisS, offsetS, point), coordinates(axisT, offsetT, point), 0)
    end
    local cells, points = 2 ^ power, {}
    for row = 0, cells do
        local left, right = LerpVector(row / cells, ordered[1], ordered[2]), LerpVector(row / cells, ordered[4], ordered[3])
        for column = 0, cells do
            local vertex = row * (cells + 1) + column
            seek(33, vertexStart + vertex, 20)
            local direction, amount = vector(), mapFile:ReadFloat()
            points[vertex] = LerpVector(column / cells, left, right) + direction * amount
        end
    end
    return {handle = handle, minS = minS, minT = minT, width = width, height = height,
        cells = cells, points = points, uv = uv, normal = normal}
end

-- Invert the base quad's lightmap coordinates, then use Source's alternating triangles.
local function sample(face, column, row)
    local a, b, c = face.uv[1], face.uv[4] - face.uv[1], face.uv[2] - face.uv[1]
    local d = face.uv[3] - face.uv[4] - face.uv[2] + a
    local target = Vector(face.minS + column, face.minT + row, 0) - a
    local determinant = b.x * c.y - b.y * c.x
    assert(math.abs(determinant) > .000001, "Degenerate displacement lightmap")
    local u, v = (target.x * c.y - target.y * c.x) / determinant, (b.x * target.y - b.y * target.x) / determinant
    for _ = 1, 4 do
        local error = b * u + c * v + d * (u * v) - target
        local du, dv = b + d * v, c + d * u
        local jacobian = du.x * dv.y - du.y * dv.x
        assert(math.abs(jacobian) > .000001, "Folded displacement lightmap")
        u, v = u - (error.x * dv.y - error.y * dv.x) / jacobian,
            v - (du.x * error.y - du.y * error.x) / jacobian
    end
    u, v = math.Clamp(u, 0, 1) * face.cells, math.Clamp(v, 0, 1) * face.cells
    local x, y = math.min(math.floor(u), face.cells - 1), math.min(math.floor(v), face.cells - 1)
    local fu, fv, stride = u - x, v - y, face.cells + 1
    local base = y * stride + x
    local ia, ib, ic, wa, wb, wc
    if base % 2 == 1 then
        if fu + fv <= 1 then
            ia, ib, ic, wa, wb, wc = base, base + stride, base + 1, 1 - fu - fv, fv, fu
        else
            ia, ib, ic, wa, wb, wc = base + 1, base + stride, base + stride + 1, 1 - fv, 1 - fu, fu + fv - 1
        end
    elseif fv >= fu then
        ia, ib, ic, wa, wb, wc = base, base + stride, base + stride + 1, 1 - fv, fv - fu, fu
    else
        ia, ib, ic, wa, wb, wc = base, base + stride + 1, base + 1, 1 - fu, fv, fu - fv
    end
    local pa, pb, pc = face.points[ia], face.points[ib], face.points[ic]
    local normal = (pb - pa):Cross(pc - pa):GetNormalized()
    if normal:Dot(face.normal) < 0 then normal = -normal end
    return pa * wa + pb * wb + pc * wc, normal,
        u > .01 and u < face.cells - .01 and v > .01 and v < face.cells - .01
end

function GC.StartDisplacementLighting()
    GC.StopDisplacementLighting()
    mapFile = assert(file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME"), "Map BSP is unavailable")
    assert(mapFile:Read(4) == "VBSP" and mapFile:ReadLong() == 20, "Unsupported BSP format")
    lumps, queue, index = {}, {}, 1
    for lump = 0, 63 do
        lumps[lump] = {offset = mapFile:ReadLong(), length = mapFile:ReadLong(), version = mapFile:ReadLong(), compressed = mapFile:ReadLong()}
    end
    report = {pending = lumps[26].length / 176, expected = lumps[26].length / 176, registered = 0, flipped = 0,
        buildMs = 0, maxBuildMs = 0, failures = {}, playArea = {samples = 0, maximumError = 0, missed = 0}}
    if report.expected == 0 then
        mapFile:Close()
        mapFile, lumps, queue, index = nil, nil, nil, nil
        return
    end
    for record = 0, report.expected - 1 do queue[#queue + 1] = record end
end

function GC.StopDisplacementLighting()
    if mapFile then mapFile:Close() end
    if bytes then bytes:Close() end
    mapFile, lumps, queue, index = nil, nil, nil, nil
    current, bytes, pixel = nil, nil, nil
    file.Delete("garrycraft-displacement-lighting.dat")
    report.pending = 0
end

function GC.DisplacementLightingReport() return report end

-- Build terrain luxels within a two-millisecond frame budget. Upload only complete faces.
hook.Add("Think", "GarryCraftDisplacementLightmaps", function()
    if not queue then return end
    local started = SysTime()
    if not current then
        current, pixel = readFace(queue[index]), 0
        bytes = assert(file.Open("garrycraft-displacement-lighting.dat", "wb", "DATA"))
    end
    local face = current
    while pixel < face.width * face.height do
        local row, column = math.floor(pixel / face.width), pixel % face.width
        local point, normal, interior = sample(face, column, row)
        bytes:WriteFloat(point.x) bytes:WriteFloat(point.y) bytes:WriteFloat(point.z)
        bytes:WriteFloat(normal.x) bytes:WriteFloat(normal.y) bytes:WriteFloat(normal.z)
        -- Seam padding can lie outside the collision quad. Verify its interior against Source.
        if GC.DisplacementLightingVerify and interior and (row * face.width + column) % 64 == 0 and math.abs(point.x) < 4000
            and math.abs(point.y) < 6000 and math.abs(point.z) < 1000 then
            local trace = util.TraceLine({start = point + normal * 2, endpos = point - normal * 2,
                mask = MASK_SOLID_BRUSHONLY})
            if not trace.StartSolid then
                local area = report.playArea
                area.samples = area.samples + 1
                if not trace.Hit then area.missed = area.missed + 1 end
                area.maximumError = math.max(area.maximumError, trace.Hit and trace.HitPos:Distance(point) or 4)
                if not trace.Hit or trace.HitPos:Distance(point) >= .5 then
                    report.failures[#report.failures + 1] = {handle = face.handle, row = row, column = column,
                        position = tostring(point), normal = tostring(normal), hit = trace.Hit,
                        error = trace.Hit and trace.HitPos:Distance(point) or 4}
                end
                if trace.Hit and trace.HitNormal:Dot(normal) < 0 then report.flipped = report.flipped + 1 end
            end
        end
        pixel = pixel + 1
        if pixel % 16 == 0 and SysTime() - started >= .002 then break end
    end
    if pixel == face.width * face.height then
        bytes:Close()
        garrycraft_bridge.source_lightmaps_set_displacement(face.handle, file.Read("garrycraft-displacement-lighting.dat", "DATA"))
        report.registered, report.pending, index = report.registered + 1, report.pending - 1, index + 1
        current, bytes, pixel = nil, nil, nil
        if report.pending == 0 then
            mapFile:Close()
            mapFile, lumps, queue, index = nil, nil, nil, nil
            file.Delete("garrycraft-displacement-lighting.dat")
        end
    end
    report.buildMs = (SysTime() - started) * 1000
    report.maxBuildMs = math.max(report.maxBuildMs, report.buildMs)
end)
