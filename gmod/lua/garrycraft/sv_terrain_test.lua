local GC = GarryCraft
local request, npc, phase
local trace = {}
local burns = {fire = 0, lava = 0}
local health = {}
local position

function GC.RunTerrainTest(owner)
    assert(game.SinglePlayer(), "Terrain tests require local single-player")
    if IsValid(npc) then npc:Remove() end
    if game.GetMap() == "gm_construct" then owner:SetPos(Vector(576, -896, -144)) end
    request = "terrain:" .. tostring(SysTime())
    GC.BeginTest(owner, request)
    npc = ents.Create("npc_citizen")
    npc:SetModel("models/Humans/Group01/male_07.mdl")
    npc:SetName("garrycraft-terrain-npc")
    position = owner:GetPos() + GC.DirectionToSource(2, 0, 2)
    npc:SetPos(position)
    npc:Spawn()
    npc:SetHealth(10000)
    npc:SetMoveType(MOVETYPE_NONE)
    npc:CapabilitiesRemove(CAP_MOVE_GROUND)
    npc:AddFlags(FL_FROZEN)
    npc:SetSchedule(SCHED_NPC_FREEZE)
    phase = nil
    trace, health, burns = {}, {}, {fire = 0, lava = 0}
end

hook.Add("EntityTakeDamage", "GarryCraftTerrainBurnTest", function(entity, damage)
    if entity == npc and burns[phase] and damage:IsDamageType(DMG_BURN) and damage:GetDamage() > 0 then
        burns[phase] = burns[phase] + 1
    end
end)

function GC.TerrainTestSample(owner, state)
    if not request or state.terrainTestRequest ~= request then return end
    local nextPhase = state.terrainTestPhase
    npc:SetPos(position)
    npc:SetSchedule(SCHED_NPC_FREEZE)
    if nextPhase == "breaking" then owner:SetEyeAngles(Angle(state.terrainTestPitch, -state.terrainTestYaw - 90, 0)) end
    if phase ~= nextPhase then
        if phase == "fire" or phase == "lava" then health[phase].after = npc:Health() end
        phase = nextPhase
        if phase == "fire" or phase == "lava" then health[phase] = {before = npc:Health()} end
    end
    trace[#trace + 1] = {phase = phase, health = npc:Health(), hitAck = GC.EntitiesAck()}
    if phase == "done" then
        file.Write("garrycraft-terrain-source.json", util.TableToJSON({request = request, trace = trace, burns = burns, health = health}))
        owner:ConCommand("garrycraft_effects_report\ngarrycraft_world_report\n")
        npc:Remove()
        request = nil
    end
end
