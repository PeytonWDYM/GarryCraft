local GC = GarryCraft
local session, tick, previous, distance, right

-- Source movement is overridden. Use Minecraft's grounded displacement with Source surface sounds.
function GC.Footsteps(player, state)
    local position = GC.ToSource(state.x, state.y, state.z)
    if session ~= state.session then
        session, tick, previous, distance, right = state.session, nil, position, 0, false
    end
    if tick == state.tick then return end
    tick = state.tick
    local moved = Vector(position.x - previous.x, position.y - previous.y, 0):Length()
    previous = position
    if not state.grounded or state.inWater or state.flying or state.gliding or state.screenOpen
            or state.sneaking or moved > 128 or moved < .01 then distance = 0 return end
    distance = distance + moved
    if distance < 48 then return end
    distance = distance % 48
    local trace = util.TraceLine({start = position + Vector(0, 0, 8), endpos = position - Vector(0, 0, 16),
        mask = MASK_PLAYERSOLID, filter = player})
    -- Minecraft already plays its own block steps. This handles only native Source surfaces.
    if not trace.Hit or IsValid(trace.Entity) and trace.Entity:GetClass() == "gc_block" then return end
    local surface = util.GetSurfaceData(trace.SurfaceProps)
    local sound = right and surface.stepRightSound or surface.stepLeftSound
    local foot = right and 1 or 0
    right = not right
    local recipients = RecipientFilter()
    recipients:AddAllPlayers()
    if sound ~= "" and hook.Run("PlayerFootstep", player, position, foot, sound, .5, recipients) ~= true then
        player:EmitSound(sound, 70, 100, .5, CHAN_BODY)
    end
end
