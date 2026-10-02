-- Owned single-player E2E: walk down a native convex ramp using Minecraft movement.
concommand.Add("garrycraft_test_slope", function(caller, _, arguments)
    assert(game.SinglePlayer(), "Slope tests require single-player")
    local GC = GarryCraft
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    local jumping = arguments[1] == "jump"
    local previous, angles = owner:GetPos(), owner:EyeAngles()
    GC.Stop()
    local origin = Vector(0, 0, 8192)
    local ramp = ents.Create("gc_fixture")
    ramp:SetPos(origin)
    ramp:SetNWVector("Minimum", Vector(-128, -512, 0))
    ramp:SetNWVector("Maximum", Vector(128, 512, 256))
    ramp:SetNWBool("Ramp", true)
    ramp:SetNWBool("GarryCraftStatic", true)
    ramp:Spawn()
    ramp:EnableCustomCollisions(true)
    owner:SetPos(origin + Vector(0, -384, 230))
    owner:SetEyeAngles(Angle(0, 90, 0))
    GC.Start(owner, 60)
    local samples, lastTick, started, startTick = {}, -1, false, 0
    local currentState
    local previousSample = GC.PolishSample
    GC.PolishSample = function(state) previousSample(state) currentState = state end
    local deadline = RealTime() + 60
    local function finish()
        hook.Remove("Think", "GarryCraftSlopeTest")
        GC.PolishSample = previousSample
        owner:ConCommand("-forward")
        owner:ConCommand("-jump")
        GC.Stop()
        ramp:Remove()
        owner:SetPos(previous)
        owner:SetEyeAngles(angles)
        local checked, failed, maxGap, airTicks = 0, 0, 0, 0
        for _, sample in ipairs(samples) do
            if sample.tick > 10 then
                checked = checked + 1
                maxGap = math.max(maxGap, math.abs(sample.gap))
                if not sample.grounded then airTicks = airTicks + 1 end
                if not sample.nativeHit or not sample.grounded or math.abs(sample.gap) > .01 then failed = failed + 1 end
            end
        end
        local first, last = samples[1], samples[#samples]
        local progressed = first and last and last.y - first.y > 128 and first.z - last.z > 32 or false
        local contactPassed = jumping and maxGap > .5 and airTicks >= 3 or not jumping and failed == 0
        file.Write("garrycraft-slope.json", util.TableToJSON({passed = checked >= 40 and progressed and contactPassed,
            jumping = jumping, progressed = progressed, airTicks = airTicks,
            checked = checked, failed = failed, maxGap = maxGap, samples = samples}, true))
    end
    hook.Add("Think", "GarryCraftSlopeTest", function()
        if RealTime() > deadline or not GC.IsActive() then finish() return end
        local state = currentState
        if not state or not state.linked or state.tick == lastTick then return end
        lastTick = state.tick
        if not started then
            if not state.grounded then return end
            started, startTick = true, state.tick
            owner:ConCommand("+forward")
        end
        local feet = GC.ToSource(state.x, state.y, state.z)
        if jumping and state.tick - startTick == 20 then owner:ConCommand("+jump") end
        if jumping and state.tick - startTick == 22 then owner:ConCommand("-jump") end
        local trace = util.TraceHull({start = feet + Vector(0, 0, 16), endpos = feet - Vector(0, 0, 128),
            mins = Vector(-9.6, -9.6, 0), maxs = Vector(9.6, 9.6, state.height * 32),
            filter = owner, mask = MASK_PLAYERSOLID})
        samples[#samples + 1] = {tick = state.tick - startTick, grounded = state.grounded,
            x = feet.x, y = feet.y, z = feet.z, nativeHit = trace.Hit,
            gap = (feet.z - trace.HitPos.z) / 32}
        if state.tick - startTick >= 60 then finish() end
    end)
end)
