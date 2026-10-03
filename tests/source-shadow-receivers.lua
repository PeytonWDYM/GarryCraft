-- Run on the client in an owned single-player gm_construct lab with RTT shadows enabled through the console.
-- Failure cases: backing-cube silhouettes, unsupported model receivers, hidden faces, camera/HDR drift,
-- missing cast callbacks, receiver opt-in gates, receiver-height errors, wall projection errors, stale handles, and incomplete cleanup.
-- Shadow direction and distance have no public getters. This explicit lab override lasts until map reload.
assert(game.SinglePlayer() and game.GetMap() == "gm_construct", "Use an owned gm_construct lab")
assert(GetConVar("r_shadows"):GetBool() and GetConVar("r_shadowrendertotexture"):GetBool(), "Enable Source RTT shadows through the console")

local id, prefix = "GarryCraftShadowReceivers", "garrycraft-source-shadow-receivers"
local bridge, model = garrycraft_bridge, "models/hunter/blocks/cube025x025x025.mdl"
-- The mesh variant keeps the same receiver planes and assertions without RenderMultiply or SetMaterial.
local receiverGeometry = GarryCraftShadowReceiverGeometry or "model"
assert(receiverGeometry == "model" or receiverGeometry == "mesh", "Receiver geometry must be model or mesh")
local view, target = Vector(900, -900, 600), Vector(1240, 0, 180)
local angles, direction = (target - view):Angle(), Vector(1, 0, -.6):GetNormalized()
local player, savedCamera = LocalPlayer(), (hook.GetTable().CalcView or {}).GarryCraftCamera
local playerWasCasting = not player:IsEffectActive(EF_NOSHADOW)
local baseline, owned, casters, samples, meshes, captures = bridge.shadow_stats(), {}, {}, {}, {}, {}
local report = {camera = {origin = {view.x, view.y, view.z}, angles = {angles.p, angles.y, angles.r}, fov = 64},
    override = {direction = {direction.x, direction.y, direction.z}, distance = 2048, restore = "Map reload required"},
    nativeBefore = baseline, receiverGeometry = receiverGeometry, receivers = {}, captures = captures}
local phase, started, advance, finished = "setup", 0, false, false
local phases, settle = {"off", "offCheck", "on", "backOff"}, {off = 2, offCheck = .5, on = 2, backOff = 1.5}

local function xyz(vector) return {vector.x, vector.y, vector.z} end

local function cleanup()
    hook.Remove("Think", id)
    hook.Remove("PostRender", id)
    hook.Remove("CalcView", id)
    hook.Remove("PreDrawViewModel", id)
    hook.Remove("PreDrawPlayerHands", id)
    if savedCamera then hook.Add("CalcView", "GarryCraftCamera", savedCamera) end
    for _, entity in ipairs(owned) do
        if IsValid(entity) then
            entity:SetNoDraw(true)
            bridge.shadow_remove(entity)
            entity:DestroyShadow()
            entity:Remove()
        end
    end
    for _, mesh in ipairs(meshes) do mesh:Destroy() end
    -- A linked human stays hidden because Minecraft's avatar owns its shadow.
    local linkedHuman = GarryCraft and GarryCraft.State and GarryCraft.State.linked and player:GetNWBool("GarryCraft")
    player:DrawShadow(playerWasCasting and not linkedHuman)
    report.nativeAfter = bridge.shadow_stats()
    report.cleanupPassed = report.nativeAfter.registered == baseline.registered
        and report.nativeAfter.registeredReceivers == baseline.registeredReceivers
        and report.nativeAfter.staleEntities == baseline.staleEntities
        and report.nativeAfter.invalidMeshes == baseline.invalidMeshes
        and report.nativeAfter.wrongThread == baseline.wrongThread
        and report.nativeAfter.receiverForwarding == baseline.receiverForwarding
    report.passed = report.passed and report.cleanupPassed and not report.error
    file.Write(prefix .. ".json", util.TableToJSON(report, true))
    print("Source RTT receiver probe: " .. (report.passed and "PASS" or "FAIL") .. " (DATA/" .. prefix .. ".json)")
end

local function setup()
    local triangles = util.GetModelMeshes(model)[1].triangles
    local minimum, maximum = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
    for _, vertex in ipairs(triangles) do for axis = 1, 3 do
        minimum[axis] = math.min(minimum[axis], vertex.pos[axis])
        maximum[axis] = math.max(maximum[axis], vertex.pos[axis])
    end end
    local size, center = maximum - minimum, (minimum + maximum) * .5
    local casterMaterial = CreateMaterial("garrycraft/shadow-receiver-caster", "VertexLitGeneric", {
        ["$basetexture"] = "color/white", ["$model"] = 1, ["$color2"] = "[0.7 0.4 0.2]"})
    local receiverMaterial = CreateMaterial("garrycraft/shadow-receiver-surface", "VertexLitGeneric", {
        ["$basetexture"] = "color/white", ["$model"] = 1, ["$color2"] = "[0.8 0.8 0.8]"})
    local casterSize = Vector(32, 64, 48)
    local vertices = {}
    for index, vertex in ipairs(triangles) do
        vertices[index] = {pos = Vector((vertex.pos.x - center.x) * casterSize.x / size.x,
            (vertex.pos.y - center.y) * casterSize.y / size.y, (vertex.pos.z - center.z) * casterSize.z / size.z),
            normal = vertex.normal, u = vertex.u, v = vertex.v, userdata = vertex.userdata}
    end
    local mesh = Mesh(casterMaterial)
    meshes[#meshes + 1] = mesh
    mesh:BuildFromTriangles(vertices)
    local class = "garrycraft_shadow_receiver_probe"
    scripted_ents.Register({Type = "anim", Base = "base_anim", RenderGroup = RENDERGROUP_OPAQUE,
        Initialize = function(self) self:SetModel(model) self:SetSolid(SOLID_NONE) self:SetMoveType(MOVETYPE_NONE) end,
        GetRenderMesh = function(self)
            if self.ProbeReceiverMesh then return {Mesh = self.ProbeReceiverMesh, Material = receiverMaterial, Matrix = Matrix()} end
            if self.ProbeCaster then return {Mesh = mesh, Material = casterMaterial, Matrix = Matrix()} end
        end,
        Draw = function(self, flags) self:DrawModel(flags) end}, class)

    local fixtures = {
        {name = "floorLow", position = Vector(1240, -260, 104), dimensions = Vector(240, 180, 8),
            caster = Vector(1120, -260, 196), normal = Vector(0, 0, 1), axis = 3, plane = 108, u = 1, v = 2},
        {name = "floorHigh", position = Vector(1240, 0, 168), dimensions = Vector(240, 180, 8),
            caster = Vector(1120, 0, 260), normal = Vector(0, 0, 1), axis = 3, plane = 172, u = 1, v = 2},
        {name = "wall", position = Vector(1310, 260, 168), dimensions = Vector(8, 180, 192),
            caster = Vector(1208, 260, 260), normal = Vector(-1, 0, 0), axis = 1, plane = 1306, u = 2, v = 3}}
    for _, fixture in ipairs(fixtures) do
        local receiver = ents.CreateClientside(class)
        assert(IsValid(receiver), "Source receiver creation failed")
        owned[#owned + 1] = receiver
        local scale = Vector(fixture.dimensions.x / size.x, fixture.dimensions.y / size.y, fixture.dimensions.z / size.z)
        receiver:SetPos(fixture.position - Vector(center.x * scale.x, center.y * scale.y, center.z * scale.z))
        receiver:Spawn()
        if receiverGeometry == "mesh" then
            local receiverVertices = {}
            for index, vertex in ipairs(triangles) do
                receiverVertices[index] = {pos = Vector((vertex.pos.x - center.x) * scale.x,
                    (vertex.pos.y - center.y) * scale.y, (vertex.pos.z - center.z) * scale.z),
                    normal = vertex.normal, u = vertex.u, v = vertex.v, userdata = vertex.userdata}
            end
            local receiverMesh = Mesh(receiverMaterial)
            meshes[#meshes + 1] = receiverMesh
            receiverMesh:BuildFromTriangles(receiverVertices)
            receiver.ProbeReceiverMesh = receiverMesh
            receiver:SetPos(fixture.position)
        else
            local matrix = Matrix() matrix:SetScale(scale)
            receiver:EnableMatrix("RenderMultiply", matrix)
            receiver:SetMaterial(receiverMaterial:GetName())
        end
        receiver:SetRenderBounds(-fixture.dimensions * .5, fixture.dimensions * .5)
        receiver:DrawShadow(false)
        bridge.shadow_receive(receiver, true)
        fixture.entity, fixture.minimum, fixture.maximum = receiver, fixture.position - fixture.dimensions * .5, fixture.position + fixture.dimensions * .5
        local caster = ents.CreateClientside(class)
        assert(IsValid(caster), "Source caster creation failed")
        owned[#owned + 1] = caster
        caster.ProbeCaster = true
        caster:SetPos(fixture.caster) caster:Spawn()
        caster:SetRenderBounds(-casterSize * .5, casterSize * .5)
        caster:DrawShadow(false)
        bridge.shadow_update(caster, {{mesh = mesh, material = casterMaterial, matrix = Matrix()}})
        casters[#casters + 1] = caster
        fixture.shadowMin, fixture.shadowMax = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
        for _, x in ipairs({-16, 16}) do for _, y in ipairs({-32, 32}) do for _, z in ipairs({-24, 24}) do
            local point = fixture.caster + Vector(x, y, z)
            point = point + direction * ((fixture.plane - point[fixture.axis]) / direction[fixture.axis])
            for axis = 1, 3 do
                fixture.shadowMin[axis] = math.min(fixture.shadowMin[axis], point[axis])
                fixture.shadowMax[axis] = math.max(fixture.shadowMax[axis], point[axis])
            end
        end end end
        local row = {name = fixture.name, position = xyz(fixture.position), dimensions = xyz(fixture.dimensions),
            caster = xyz(fixture.caster), casterDimensions = xyz(casterSize), surface = fixture.plane,
            projectedMinimum = xyz(fixture.shadowMin), projectedMaximum = xyz(fixture.shadowMax), points = {}}
        report.receivers[#report.receivers + 1] = row
        fixture.row = row
    end
    -- Sample the real receiver faces. Reject points hidden by fixture boxes or BSP geometry.
    local function blocked(point, fixture)
        for _, other in ipairs(fixtures) do
            local boxes = {{other.caster - casterSize * .5, other.caster + casterSize * .5}}
            if other ~= fixture then boxes[#boxes + 1] = {other.minimum, other.maximum} end
            for _, box in ipairs(boxes) do
                local near, far, delta = 0, 1, point - view
                for axis = 1, 3 do
                    if math.abs(delta[axis]) < .0001 then
                        if view[axis] < box[1][axis] or view[axis] > box[2][axis] then far = -1 end
                    else
                        local a, b = (box[1][axis] - view[axis]) / delta[axis], (box[2][axis] - view[axis]) / delta[axis]
                        near, far = math.max(near, math.min(a, b)), math.min(far, math.max(a, b))
                    end
                end
                if near <= far and far >= 0 and near < .999 then return true end
            end
        end
        return util.TraceLine({start = view, endpos = point, mask = MASK_SOLID_BRUSHONLY}).Hit
    end
    for _, fixture in ipairs(fixtures) do
        for u = fixture.minimum[fixture.u] + 8, fixture.maximum[fixture.u] - 8, 4 do
            for v = fixture.minimum[fixture.v] + 8, fixture.maximum[fixture.v] - 8, 4 do
                local point = Vector() point[fixture.axis] = fixture.plane
                point[fixture.u], point[fixture.v] = u, v
                point = point + fixture.normal * .25
                if not blocked(point, fixture) then
                    local expected = u > fixture.shadowMin[fixture.u] + 4 and u < fixture.shadowMax[fixture.u] - 4
                        and v > fixture.shadowMin[fixture.v] + 4 and v < fixture.shadowMax[fixture.v] - 4
                    samples[#samples + 1] = {world = point, row = fixture.row, expected = expected}
                end
            end
        end
    end
    hook.Remove("CalcView", "GarryCraftCamera")
    hook.Add("CalcView", id, function() return {origin = view, angles = angles, fov = 64, drawviewer = false} end)
    hook.Add("PreDrawViewModel", id, function() return true end)
    hook.Add("PreDrawPlayerHands", id, function() return true end)
    player:DrawShadow(false)
    render.SetShadowDirection(direction) render.SetShadowDistance(2048)
    phase, started = "off", RealTime()
end

local function compare()
    report.passed = captures.on.native.castDraws - captures.off.native.castDraws >= #casters
        and captures.on.native.receiverLinks > captures.off.native.receiverLinks
        and captures.on.native.receiverQueries > captures.off.native.receiverQueries
    for _, row in ipairs(report.receivers) do
        local result = {expected = 0, darkened = 0, reversible = 0, control = 0, controlDarkened = 0, unstable = 0}
        for _, point in ipairs(row.points) do
            local index = point.index
            local a, b, on, back = captures.off.pixels[index], captures.offCheck.pixels[index], captures.on.pixels[index], captures.backOff.pixels[index]
            local function light(rgb) return (rgb[1] + rgb[2] + rgb[3]) / 3 end
            local noise = math.abs(light(a) - light(b))
            local threshold = math.max(6, noise * 3)
            local dark = light(b) - light(on) >= threshold
            if point.expected then
                result.expected = result.expected + 1
                if noise > 3 then result.unstable = result.unstable + 1 end
                if dark then
                    result.darkened = result.darkened + 1
                    if light(back) - light(on) >= threshold and math.abs(light(back) - light(b)) <= threshold then
                        result.reversible = result.reversible + 1
                    end
                end
            else
                result.control = result.control + 1
                if dark then result.controlDarkened = result.controlDarkened + 1 end
            end
        end
        result.passed = result.expected >= 20 and result.darkened >= math.max(8, result.expected * .1)
            and result.reversible >= result.darkened * .75 and result.unstable <= result.expected * .05
            and result.control > 20 and result.controlDarkened <= result.control * .05
        row.result = result
        report.passed = report.passed and result.passed
    end
end

hook.Add("Think", id, function()
    local ok, message = xpcall(function()
        if finished then cleanup() return end
        if phase == "setup" then setup() return end
        if not advance then return end
        advance = false
        local nextIndex = table.KeyFromValue(phases, phase) + 1
        if nextIndex > #phases then compare() finished = true cleanup() return end
        phase, started = phases[nextIndex], RealTime()
        for _, caster in ipairs(casters) do
            caster:DrawShadow(phase == "on")
            if phase == "on" then caster:CreateShadow() caster:MarkShadowAsDirty() else caster:DestroyShadow() end
        end
    end, debug.traceback)
    if not ok then report.error = message report.passed = false cleanup() end
end)

hook.Add("PostRender", id, function()
    if phase == "setup" or finished or advance or RealTime() - started < settle[phase] then return end
    local ok, message = xpcall(function()
        file.Write(prefix .. "-" .. phase .. ".png", render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        render.CapturePixels()
        if phase == "off" then
            cam.Start3D(view, angles, 64, 0, 0, ScrW(), ScrH())
            local seen = {}
            for _, sample in ipairs(samples) do
                local screen = sample.world:ToScreen()
                local x, y = math.floor(screen.x), math.floor(screen.y)
                local key = sample.row.name .. ":" .. x .. ":" .. y
                if screen.visible and x >= 0 and y >= 0 and x < ScrW() and y < ScrH() and not seen[key] then
                    seen[key] = true
                    sample.row.points[#sample.row.points + 1] = {world = xyz(sample.world), screen = {x, y}, expected = sample.expected}
                end
            end
            cam.End3D()
            report.resolution = {ScrW(), ScrH()}
        end
        assert(ScrW() == report.resolution[1] and ScrH() == report.resolution[2], "Resolution changed during the receiver probe")
        local pixels = {}
        for _, row in ipairs(report.receivers) do for _, point in ipairs(row.points) do
            local r, g, b = render.ReadPixel(point.screen[1], point.screen[2])
            pixels[#pixels + 1] = {r, g, b}
            point.index = #pixels
        end end
        local modelShadow = Material("decals/rendermodelshadow")
        local atlas = modelShadow:GetTexture("$basetexture")
        captures[phase] = {pixels = pixels, native = bridge.shadow_stats(),
            modelShadow = {error = modelShadow:IsError(), shader = modelShadow:GetShader(),
                texture = atlas and atlas:GetName(), width = atlas and atlas:Width(), height = atlas and atlas:Height(),
                falloffOffset = modelShadow:GetFloat("$falloffoffset"), falloffDistance = modelShadow:GetFloat("$falloffdistance"),
                falloffAmount = modelShadow:GetFloat("$falloffamount")}}
        advance = true
    end, debug.traceback)
    if not ok then report.error = message report.passed = false finished = true end
end)
