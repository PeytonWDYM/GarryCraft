-- Observe the installed gun during real walk, sprint, stop, and hotbar inputs.
-- Failures: missing skin meshes, native hands leakage, frozen bob, detached rear elbow,
-- stale hands after selection changes, or a transform that differs from Minecraft's render pose.
assert(CLIENT and game.SinglePlayer(), "Use the client in an owned single-player lab")
local GC = GarryCraft
local run, phase, capture, drawnFrame
local name = "GarryCraftPhysgunViewmodelProbe"
local function vector(value) return {value.x, value.y, value.z} end
local function angle(value) return {value.p, value.y, value.r} end
local function save()
    file.Write("garrycraft-physgun-viewmodel.json", util.TableToJSON(run, true))
end
GC.PhysgunViewmodelTest = {}
function GC.PhysgunViewmodelTest.Begin(label)
    assert(not run and GC.PhysgunActive(LocalPlayer()), "Select the Minecraft physics gun before Begin")
    assert(GC.State.camera == 0, "Use first person")
    run = {label = label, started = RealTime(), map = game.GetMap(), frames = {}, images = {},
        inputDriver = "Windows keyboard and mouse", scenarios = {"idle", "walk", "sprint", "stop", "switch-away", "switch-back"}}
    phase, capture = "idle", RealTime() + .4
    hook.Add("PostDrawViewModel", name, function(model)
        if not run or #run.frames >= 8000 then return end
        local state = GC.State
        local applied = GC.PhysgunViewmodelReport()
        local offset, rotation = WorldToLocal(model:GetPos(), model:GetAngles(), Vector(unpack(applied.viewOrigin)), Angle(unpack(applied.viewAngles)))
        local transform, fields = Matrix(), {}
        transform:SetTranslation(offset)
        transform:SetAngles(rotation)
        for row = 1, 3 do for column = 1, 4 do fields[#fields + 1] = transform:GetField(row, column) end end
        drawnFrame = {phase = phase, time = RealTime() - run.started,
            equipped = GC.PhysgunEquipped(), active = GC.PhysgunActive(LocalPlayer()),
            offset = vector(offset), rotation = angle(rotation),
            walk = state.walk, bob = state.bob, sprinting = state.sprinting,
            minecraftPose = applied.minecraftPose, measuredTransform = fields,
            latestPacketFrame = state.frame, bobPose = applied}
    end)
    hook.Add("PostRender", name, function()
        -- Player hands draw after PostDrawViewModel. Inspect the completed frame and the packet actually applied.
        if drawnFrame then
            drawnFrame.native = GC.NativeItemReport()
            run.frames[#run.frames + 1] = drawnFrame
            drawnFrame = nil
        end
        if not capture or RealTime() < capture then return end
        capture = nil
        render.CapturePixels()
        local pixels = {}
        -- Keep both lower-screen hand regions as repeatable pixel evidence.
        for y = 1, 12 do for x = 1, 24 do
            local r, g, b = render.ReadPixel(math.floor(ScrW() * x / 25), math.floor(ScrH() * (.55 + y * .4 / 13)))
            pixels[#pixels + 1] = {r, g, b}
        end end
        local path = "garrycraft-physgun-viewmodel-" .. phase .. ".png"
        file.Write(path, render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false}))
        run.images[#run.images + 1] = {phase = phase, path = path, width = ScrW(), height = ScrH(), pixels = pixels,
            equipped = GC.PhysgunEquipped(), native = GC.NativeItemReport()}
        save()
    end)
    save()
end
function GC.PhysgunViewmodelTest.Mark(label)
    assert(run, "Begin the viewmodel probe first")
    phase, capture = label, RealTime() + .4
    save()
end
function GC.PhysgunViewmodelTest.Finish()
    assert(run, "Begin the viewmodel probe first")
    hook.Remove("PostDrawViewModel", name)
    hook.Remove("PostRender", name)
    run.finished = true
    save()
    run = nil
end
