-- Copy origin/main's sv_geometry.lua to DATA/gc-old-geometry.lua before loading this test.
concommand.Add("garrycraft_test_export", function(owner)
    assert(game.SinglePlayer(), "Export benchmarks require a local single-player map")
    local GC = GarryCraft
    local currentStatic, currentDynamic = GC.StaticGeometry, GC.DynamicGeometry
    local function measure(export)
        local times, triangles = {}, 0
        for index = 1, 105 do
            local start = SysTime()
            triangles = #export(owner)
            if index > 5 then times[#times+1] = (SysTime()-start)*1000 end
        end
        table.sort(times)
        return {triangles=triangles,p50=times[50],p95=times[95],p99=times[99],samples=#times}
    end
    RunString(file.Read("gc-old-geometry.lua", "DATA"))
    local old = measure(GC.DynamicGeometry)
    GC.StaticGeometry, GC.DynamicGeometry = currentStatic, currentDynamic
    local current = measure(currentDynamic)
    local start = SysTime()
    local batches = currentStatic()
    local triangles = 0
    for _, batch in ipairs(batches) do triangles = triangles + #batch end
    local report = {map=game.GetMap(),entities=#ents.GetAll(),before=old,after=current,
        staticMs=(SysTime()-start)*1000,staticTriangles=triangles,props=GC.StaticPropReport}
    file.Write("garrycraft-export-benchmark.json",util.TableToJSON(report,true))
end)
