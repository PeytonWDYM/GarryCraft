local GC = GarryCraft
local enabled = CreateClientConVar("garrycraft_sun_shadows", "1", true, false,
    "Enable one nearby Source sun projector for Minecraft shadows", 0, 1)
local projector, session, instance
local target, direction, color
local distance, fov, brightness = 768, 45, .35
local created, removed, updates, updateMs = 0, 0, 0, 0
local reason = "inactive"

-- One perspective shadow map covers a nearby footprint. Source ambient remains unchanged.
function GC.StopSun()
    if projector then projector:Remove() projector = nil removed = removed + 1 end
    target, direction, color, session, instance = nil, nil, nil, nil, nil
end

local function active()
    local player = LocalPlayer()
    return enabled:GetBool() and not GC.VideoReset and GC.State and GC.State.linked
        and IsValid(player) and player:GetNWBool("GarryCraft") and player:Alive()
        and GC.State.teleportAck == player:GetNWInt("GarryCraftTeleport")
end

-- Cleanup also runs when Source stops drawing the linked view.
hook.Add("Think", "GarryCraftSunLifecycle", function()
    if not active() then reason = "inactive" GC.StopSun()
    elseif projector and (session ~= GC.State.session or instance ~= GC.State.renderInstance) then
        reason = "session changed" GC.StopSun()
    end
end)
cvars.AddChangeCallback("garrycraft_sun_shadows", function(_, _, value)
    if tonumber(value) ~= 1 then reason = "disabled" GC.StopSun() end
end, "GarryCraftSunShadows")
hook.Add("ShutDown", "GarryCraftSunCleanup", GC.StopSun)

hook.Add("PreDrawOpaqueRenderables", "GarryCraftSun", function(depth, skybox)
    if depth or skybox then return end
    if not active() or not GC.ViewOrigin then reason = "inactive" GC.StopSun() return end
    local sun = util.GetSunInfo()
    if not sun or not sun.enabled or sun.direction.z <= .05 then
        reason = "no Source sun" GC.StopSun() return
    end
    local before = SysTime()
    if projector and (session ~= GC.State.session or instance ~= GC.State.renderInstance) then GC.StopSun() end
    if not projector then
        projector = ProjectedTexture()
        projector:SetTexture("color/white")
        projector:SetFOV(fov)
        projector:SetNearZ(16)
        projector:SetFarZ(distance + 512)
        projector:SetBrightness(brightness)
        projector:SetConstantAttenuation(1)
        projector:SetLinearAttenuation(0)
        projector:SetQuadraticAttenuation(0)
        projector:SetEnableShadows(true)
        projector:SetShadowFilter(1)
        session, instance = GC.State.session, GC.State.renderInstance
        created = created + 1
    end
    local nextTarget = GC.ViewOrigin - Vector(0, 0, 36)
    local nextDirection = sun.direction:GetNormalized()
    if not target or target:DistToSqr(nextTarget) > 1 or direction ~= nextDirection then
        target, direction = nextTarget, nextDirection
        projector:SetPos(target + direction * distance)
        projector:SetAngles((-direction):Angle())
    end
    if not color or color.r ~= sun.sunColor.r or color.g ~= sun.sunColor.g or color.b ~= sun.sunColor.b then
        color = Color(sun.sunColor.r, sun.sunColor.g, sun.sunColor.b)
        projector:SetColor(color)
    end
    -- Source refreshes moving caster depth. Keep its normal frustum and PVS culling enabled.
    projector:Update()
    updates = updates + 1
    updateMs = updateMs * .9 + (SysTime() - before) * 100
    reason = "active"
end)

function GC.SunReport()
    return {enabled = enabled:GetBool(), active = projector ~= nil, reason = reason, budget = 1,
        created = created, removed = removed, updates = updates, updateMs = updateMs,
        target = target and tostring(target), direction = direction and tostring(direction),
        distance = distance, fov = fov, brightness = brightness,
        shadowResolution = GetConVar("r_flashlightdepthres"):GetInt(),
        session = session, instance = instance}
end
