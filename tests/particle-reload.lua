-- Observe actual exported Source meshes during the owned resource reload scenario.
local GC = GarryCraft
local previous = GC.AcceptWorldScene
local previousRequest = GC.State and GC.State.particleReloadRequest
local request
local instance
local maxima = {before = 0, after = 0}
GC.AcceptWorldScene = function(scene, body)
    previous(scene, body)
    instance = scene.instance
    local state = GC.State
    if not state or state.particleReloadRequest == previousRequest or
        not string.StartWith(state.particleReloadRequest or "", "reload:") then return end
    if request ~= state.particleReloadRequest then
        request = state.particleReloadRequest
        maxima = {before = 0, after = 0}
    end
    local phase = state.particleReloadPhase
    if maxima[phase] then
        local vertices = 0
        for _, batch in ipairs(scene.particles.batches) do vertices = vertices + batch.count end
        maxima[phase] = math.max(maxima[phase], vertices)
    end
end
hook.Add("Think", "GarryCraftParticleReloadTrace", function()
    local state = GC.State
    if state and request == state.particleReloadRequest and state.particleReloadPhase == "done" then
        file.Write("garrycraft-particle-reload-source.json", util.TableToJSON({request = request, completed = true,
            beforeVertices = maxima.before, afterVertices = maxima.after, renderInstance = instance}))
        GC.AcceptWorldScene = previous
        hook.Remove("Think", "GarryCraftParticleReloadTrace")
    end
end)
