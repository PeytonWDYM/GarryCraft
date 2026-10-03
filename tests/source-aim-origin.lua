-- Observe real Source aim during standing, sneaking, and native physics-gun input in an owned lab.
assert(game.SinglePlayer(), "Use an owned single-player lab")
local GC = GarryCraft
local name = "GarryCraftAimOriginTest"
GC.AimOriginTest = {}
function GC.AimOriginTest.Begin(label, seconds)
    assert(not timer.Exists(name), "Finish the previous aim observation")
    local samples = {}
    local realm = SERVER and "source" or "client"
    local started = RealTime()
    local count = math.ceil((seconds or 2) / .02)
    timer.Create(name, .02, count, function()
        local player = SERVER and player.GetHumans()[1] or LocalPlayer()
        assert(IsValid(player) and player:GetNWBool("GarryCraft"), "The bridge must remain linked")
        local expected = player:GetNWFloat("GarryCraftEye")
        local applied = player:GetCurrentViewOffset().z
        samples[#samples + 1] = {time = RealTime() - started, expected = expected, applied = applied,
            eye = tostring(player:EyePos()), shoot = tostring(player:GetShootPos()),
            position = tostring(player:GetPos()), error = math.abs(applied - expected)}
        if #samples == count then
            local passed = true
            for _, row in ipairs(samples) do if row.error > .01 then passed = false end end
            file.Write("garrycraft-aim-origin-" .. label .. "-" .. realm .. ".json",
                util.TableToJSON({passed = passed, label = label, realm = realm, samples = samples}, true))
        end
    end)
end
