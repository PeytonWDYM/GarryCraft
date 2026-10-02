-- Owned single-player fixture. Fail on a missing native ray transition or stale lighting at a fixed sample.
local GC = GarryCraft
local origin = Vector(1200, 0, 1024)
if SERVER then
    assert(game.SinglePlayer() and game.GetMap() == "gm_construct", "Use an owned gm_construct lab")
    local blocker = ents.Create("func_brush")
    blocker:SetName("garrycraft-light-visibility-blocker")
    blocker:SetPos(origin)
    -- gm_construct's first brush model is a thin wall. Clone its model without changing the installed map entity.
    blocker:SetModel("*1")
    blocker:SetKeyValue("Solidity", "2")
    blocker:Spawn()
    timer.Simple(1, function() blocker:SetPos(origin + Vector(0, 2048, 0)) end)
    timer.Simple(2, function() blocker:SetPos(origin) end)
    timer.Simple(4, function() blocker:Remove() end)
    return
end

local position, torch = origin - Vector(64, 0, 0), origin + Vector(64, 0, 0)
local light = GC.ToMinecraft(torch)
GC.SetBlockLights({fixture = {lights = {{x = light[1], y = light[2], z = light[3], emission = 15, color = 0xffcc88}}}})
local sample = {colors = {}}
local started, revision = RealTime(), GC.LightRevision()
local samples = {}
hook.Add("PostDrawTranslucentRenderables", "GarryCraftNativeLightVisibilityTest", function(depth, skybox)
    if depth or skybox then return end
    local elapsed = RealTime() - started
    GC.PrepareLighting(position, sample)
    local trace = util.TraceLine({start = position, endpos = torch, mask = MASK_SOLID_BRUSHONLY})
    samples[#samples + 1] = {elapsed = elapsed, hit = trace.Hit, class = IsValid(trace.Entity) and trace.Entity:GetClass() or "world",
        lights = #sample.lights, revision = GC.LightRevision(), position = {position.x, position.y, position.z}}
    GC.RestoreLighting()
    if elapsed < 3.5 then return end
    hook.Remove("PostDrawTranslucentRenderables", "GarryCraftNativeLightVisibilityTest")
    local checks = {closed = false, open = false, reclosed = false, fixedRevision = true, refreshed = true}
    for _, row in ipairs(samples) do
        checks.fixedRevision = checks.fixedRevision and row.revision == revision
        if row.elapsed > .3 and row.elapsed < .8 then checks.closed = checks.closed or row.hit end
        if row.elapsed > 1.4 and row.elapsed < 1.8 then checks.open = checks.open or not row.hit end
        if row.elapsed > 2.4 and row.elapsed < 3.2 then checks.reclosed = checks.reclosed or row.hit end
        if (row.elapsed > .3 and row.elapsed < .8) or (row.elapsed > 1.4 and row.elapsed < 1.8)
                or (row.elapsed > 2.4 and row.elapsed < 3.2) then
            checks.refreshed = checks.refreshed and row.lights == (row.hit and 0 or 1)
        end
    end
    local passed = true
    for _, value in pairs(checks) do passed = passed and value end
    GC.SetBlockLights({})
    file.Write("garrycraft-native-light-visibility.json", util.TableToJSON({passed = passed, checks = checks, samples = samples}, true))
end)
