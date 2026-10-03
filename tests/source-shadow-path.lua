-- Source-only engine probe. Run on the client in an owned single-player gm_construct lab.
-- The custom mesh is deliberately wider than its studio model. RTT must use the custom silhouette.
assert(game.SinglePlayer() and game.GetMap() == "gm_construct", "Use an owned gm_construct lab")
local model = "models/hunter/blocks/cube025x025x025.mdl"
local origin = Vector(1200, 0, 128)
local view = Vector(1120, -240, 256)
local material = CreateMaterial("garrycraft/source-shadow-probe", "VertexLitGeneric", {
    ["$basetexture"] = "color/white", ["$model"] = 1, ["$color2"] = "[0.7 0.4 0.2]"})
local mesh = Mesh(material)
local vertices = util.GetModelMeshes(model)[1].triangles
local minimum, maximum = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
for _, vertex in ipairs(vertices) do
    for axis = 1, 3 do
        minimum[axis] = math.min(minimum[axis], vertex.pos[axis])
        maximum[axis] = math.max(maximum[axis], vertex.pos[axis])
    end
end
for index, vertex in ipairs(vertices) do
    -- Source can share triangle vertex tables. Do not scale the same model vertex more than once.
    vertices[index] = {pos = Vector(vertex.pos.x * 96 / (maximum.x - minimum.x),
        vertex.pos.y * 32 / (maximum.y - minimum.y), vertex.pos.z * 64 / (maximum.z - minimum.z)),
        normal = vertex.normal, u = vertex.u, v = vertex.v, userdata = vertex.userdata}
end
mesh:BuildFromTriangles(vertices)
local calls, drawFlags = 0, {}
scripted_ents.Register({Type = "anim", Base = "base_anim", RenderGroup = RENDERGROUP_OPAQUE,
    Initialize = function(self)
        self:SetModel(model)
        self:SetRenderBounds(Vector(-48, -16, -32), Vector(48, 16, 32))
    end,
    GetRenderMesh = function(self)
        calls = calls + 1
        return {Mesh = mesh, Material = material, Matrix = Matrix()}
    end,
    Draw = function(self, flags)
        drawFlags[flags] = (drawFlags[flags] or 0) + 1
        self:DrawModel(flags)
    end}, "garrycraft_source_shadow_probe")
local entity = ents.CreateClientside("garrycraft_source_shadow_probe")
entity:SetPos(origin)
entity:Spawn()
garrycraft_bridge.shadow_update(entity, {{mesh = mesh, material = material, matrix = Matrix()}})
file.Write("garrycraft-source-shadow-bounds.json", util.TableToJSON({pos = entity:GetPos(), bounds = {entity:GetRenderBounds()},
    model = entity:GetModel(), scale = entity:GetModelScale(), vertices = {vertices[1].pos, vertices[2].pos, vertices[3].pos}}, true))
entity:DrawShadow(false)
LocalPlayer():DrawShadow(false)
render.SetShadowDirection(Vector(1, .25, -1):GetNormalized())
render.SetShadowDistance(2048)
hook.Add("CalcView", "GarryCraftSourceShadowProbe", function()
    return {origin = view, angles = (origin - view):Angle(), fov = 70, drawviewer = true}
end)
local start, captured = RealTime(), {}
hook.Add("PostRender", "GarryCraftSourceShadowProbe", function()
    local elapsed = RealTime() - start
    local phase = elapsed < 1.5 and "off" or elapsed < 3 and "on" or "done"
    if phase == "on" and not captured.enabled then
        entity:DrawShadow(true)
        entity:CreateShadow()
        captured.enabled = true
    end
    local name = elapsed > 1 and phase == "off" and "off" or elapsed > 2.5 and phase == "on" and "on"
    if name and not captured[name] then
        file.Write("garrycraft-source-shadow-" .. name .. ".png", render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        render.CapturePixels()
        local point = Vector(1296, 16, 64.2):ToScreen()
        local r, g, b = render.ReadPixel(math.floor(point.x), math.floor(point.y))
        captured[name] = {calls = calls, pixel = {r, g, b}, screen = {point.x, point.y},
            native = garrycraft_bridge.shadow_stats()}
    end
    if phase ~= "done" then return end
    file.Write("garrycraft-source-shadow-path.json", util.TableToJSON({captures = captured, calls = calls, flags = drawFlags}, true))
    hook.Remove("PostRender", "GarryCraftSourceShadowProbe")
    hook.Remove("CalcView", "GarryCraftSourceShadowProbe")
    timer.Simple(0, function()
        garrycraft_bridge.shadow_remove(entity)
        entity:DestroyShadow()
        entity:Remove()
        mesh:Destroy()
        LocalPlayer():DrawShadow(true)
        file.Write("garrycraft-source-shadow-cleanup.json", util.TableToJSON(garrycraft_bridge.shadow_stats(), true))
    end)
end)
