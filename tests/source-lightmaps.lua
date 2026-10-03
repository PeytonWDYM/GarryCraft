-- Read-only ABI gate before the native renderer may change any lightmap tile.
-- Failures: bad surface handles, wrong atlas rectangles, incorrect luxel matrices,
-- missing original irradiance, or vertices that do not lie on the reported plane.
assert(game.SinglePlayer(), "Use an owned single-player lab")
garrycraft_bridge.lightmap_capture_start()
render.RedownloadAllLightmaps()
timer.Simple(1, function()
    local probe = garrycraft_bridge.lightmap_probe(game.GetWorld(), 256)
    local checks = {supported = probe.supported, readOnly = not probe.mutable,
        captured = probe.captured_tiles and probe.captured_tiles > 0,
        enoughSurfaces = probe.returned and probe.returned > 20}
    local failures = {}
    for _, surface in ipairs(probe.surfaces or {}) do
        local valid = surface.capture_matches_rect and surface.mapping_candidate
        for _, point in ipairs(surface.vertices) do
            local u = surface.lightmap_s:Dot(point) + surface.lightmap_s_offset
            local v = surface.lightmap_t:Dot(point) + surface.lightmap_t_offset
            valid = valid and math.abs(surface.plane_normal:Dot(point) - surface.plane_distance) < .1
                and u >= surface.candidate_min_s - .1 and u <= surface.candidate_min_s + surface.width - 1 + .1
                and v >= surface.candidate_min_t - .1 and v <= surface.candidate_min_t + surface.height - 1 + .1
        end
        if not valid then failures[#failures + 1] = surface.handle end
    end
    checks.mapping = #failures == 0
    file.Write("garrycraft-lightmap-probe.json", util.TableToJSON({probe = probe, checks = checks, failures = failures}, true))
    garrycraft_bridge.lightmap_capture_stop()
end)
