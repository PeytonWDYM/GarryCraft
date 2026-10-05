-- A replaced studio adapter must leave the real Lua mesh update and draw path active.
assert(CLIENT and game.SinglePlayer(), "Use an owned single-player lab")
garrycraft_bridge.close()
garrycraft_shadow_test.hook_studio()
local GC = GarryCraft
local previousState, previousMaterial = GC.State, GC.RenderMaterial
local model = "models/hunter/blocks/cube025x025x025.mdl"
local origin, view = Vector(1200, 0, 128), Vector(1120, -240, 256)
local material = CreateMaterial("garrycraft/shadow-fallback", "VertexLitGeneric", {
    ["$basetexture"] = "color/white", ["$model"] = 1, ["$color2"] = "[0.7 0.4 0.2]"})
local mesh = Mesh(material)
mesh:BuildFromTriangles(util.GetModelMeshes(model)[1].triangles)
local batch = {mesh = mesh, minimum = Vector(-16, -16, -16), maximum = Vector(16, 16, 16)}
local entry = {batch = batch, kind = "world", matrix = Matrix()}
local entity = ents.CreateClientside("garrycraft_source_model")
entry.entity, entity.GarryCraftSourceModel = entity, entry
entity:SetPos(origin)
entity:Spawn()
GC.State = {linked = true}
-- The source-only probe has no bridge heartbeat. Restore its linked draw state before each frame.
hook.Add("PreRender", "GarryCraftShadowFallbackTest", function() GC.State = {linked = true} end)
GC.RenderMaterial = function(value, ...)
    if value == batch then return material end
    return previousMaterial(value, ...)
end
local transform = Matrix()
transform:SetTranslation(origin)
local before = GC.SourceModelReport().colorDraws.world
local ok, failure = pcall(function()
    for index = 1, 10 do GC.UpdateSourceModel(entry, origin, transform) end
end)
hook.Add("CalcView", "GarryCraftShadowFallbackTest", function()
    return {origin = view, angles = (origin - view):Angle(), fov = 70, drawviewer = true}
end)
timer.Simple(2, function()
    hook.Add("PostRender", "GarryCraftShadowFallbackTest", function()
        hook.Remove("PostRender", "GarryCraftShadowFallbackTest")
        file.Write("garrycraft-shadow-fallback.png", render.Capture({format="png", x=0, y=0, w=ScrW(), h=ScrH(), alpha=false}))
        file.Write("garrycraft-shadow-fallback.json", util.TableToJSON({
            updatesCompleted = ok, failure = failure, entityValid = IsValid(entity),
            shadowsDisabled = entry.shadowReady == false,
            meshDraws = GC.SourceModelReport().colorDraws.world - before,
            native = garrycraft_bridge.shadow_stats(), fixtureCalls = garrycraft_shadow_test.model_calls()
        }, true))
        timer.Simple(0, function()
            hook.Remove("CalcView", "GarryCraftShadowFallbackTest")
            hook.Remove("PreRender", "GarryCraftShadowFallbackTest")
            entity:Remove()
            mesh:Destroy()
            GC.State, GC.RenderMaterial = previousState, previousMaterial
            garrycraft_shadow_test.restore()
        end)
    end)
end)
