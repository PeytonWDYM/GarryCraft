local GC = GarryCraft
local enabled = CreateClientConVar("garrycraft_sun_shadows", "1", true, false,
    "Enable world-space directional Minecraft sunlight occlusion", 0, 1)
local direction, height
local revision = 0
local strength = .35
local reason = "inactive"

function GC.StopSun()
    if not direction then return end
    garrycraft_bridge.source_sun_lighting(direction, 0, GC.GridHeight)
    direction, height = nil, nil
    revision = revision + 1
end

-- Sun occlusion changes direct irradiance before Source shades each material.
hook.Add("Think", "GarryCraftSunLifecycle", function()
    local player = LocalPlayer()
    if not enabled:GetBool() or GC.VideoReset or not GC.State or not GC.State.linked
        or not IsValid(player) or not player:GetNWBool("GarryCraft") then
        reason = "inactive" GC.StopSun() return
    end
    local sun = util.GetSunInfo()
    if not sun or not sun.enabled or sun.direction.z <= .05 then
        reason = "no Source sun" GC.StopSun() return
    end
    local nextDirection = sun.direction:GetNormalized()
    if direction ~= nextDirection or height ~= GC.GridHeight then
        direction, height, revision = nextDirection, GC.GridHeight, revision + 1
        garrycraft_bridge.source_sun_lighting(direction, strength, height)
    end
    reason = "active"
end)
cvars.AddChangeCallback("garrycraft_sun_shadows", function(_, _, value)
    if tonumber(value) ~= 1 then GC.StopSun() end
end, "GarryCraftSunShadows")
hook.Add("ShutDown", "GarryCraftSunCleanup", GC.StopSun)

function GC.SunRevision() return revision end
function GC.SunReport()
    return {enabled = enabled:GetBool(), active = direction ~= nil, reason = reason,
        mode = "directional-irradiance", brightness = strength, direction = direction and tostring(direction),
        shadowLength = 2048, revision = revision}
end
