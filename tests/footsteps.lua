-- Run only in the owned lab. Observe real Source sound emissions without replacing movement or audio APIs.
local owner = player.GetHumans()[1]
local report = {calls=0,emitted=0,sounds={}}
hook.Add("PlayerFootstep", "GarryCraftFootstepEvidence", function(p, position, foot, sound)
    if p == owner then
        report.calls = report.calls + 1
        report.sounds[#report.sounds+1] = {time=RealTime(),foot=foot,sound=sound,position={position.x,position.y,position.z}}
    end
end)
hook.Add("EntityEmitSound", "GarryCraftFootstepEvidence", function(data)
    if data.Entity == owner and string.find(string.lower(data.OriginalSoundName), "step") then report.emitted=report.emitted+1 end
end)
timer.Create("GarryCraftFootstepEvidence", 1, 0, function()
    file.Write("garrycraft-footsteps.json",util.TableToJSON(report))
end)
concommand.Add("garrycraft_test_footsteps_stop", function()
    hook.Remove("PlayerFootstep", "GarryCraftFootstepEvidence")
    hook.Remove("EntityEmitSound", "GarryCraftFootstepEvidence")
    timer.Remove("GarryCraftFootstepEvidence")
    file.Write("garrycraft-footsteps.json",util.TableToJSON(report))
end)
