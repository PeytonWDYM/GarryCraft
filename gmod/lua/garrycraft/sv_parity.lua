local GC = GarryCraft
local targets = {}
local trace = {}
local started
local nextSample = 0
local finished = false
local looseProp
local looseStart
local largestImpulse = 0
local phase
local aiHealth
local request
local armed = false
local testOrigin

function GC.ParityStop()
    for _, entity in ipairs(targets) do if IsValid(entity) then entity:Remove() end end
    targets = {}
    if IsValid(looseProp) then looseProp:Remove() end
    looseProp = nil
    finished = true
end

function GC.RunEntityTest(caller)
    assert(game.SinglePlayer(), "GarryCraft tests require local single-player")
    for _, entity in ipairs(targets) do if IsValid(entity) then entity:Remove() end end
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    if game.GetMap() == "gm_construct" then owner:SetPos(Vector(576, -896, -144)) end
    local origin = owner:GetPos()
    local nextRequest = "entities:" .. tostring(SysTime())
    GC.BeginTest(owner, nextRequest)
    request = nextRequest
    testOrigin = origin
    owner:SetEyeAngles(Angle(0, -90, 0))
    local npc = ents.Create("npc_citizen")
    npc:SetPos(origin + Vector(0, -96, 0))
    npc:SetName("garrycraft-test-npc")
    npc:SetModel("models/Humans/Group01/male_07.mdl")
    -- Test citizens have no player squad. Keep their combat AI out of the citizen recruitment path.
    npc:SetKeyValue("spawnflags", "1048576")
    npc:Spawn()
    npc:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 64))
    npc:SetNPCState(NPC_STATE_IDLE)
    npc:SetMoveType(MOVETYPE_NONE)
    npc:CapabilitiesRemove(CAP_MOVE_GROUND)
    npc:SetSchedule(SCHED_NPC_FREEZE)
    npc:AddFlags(FL_FROZEN)
    npc.GarryCraftTestHealth = npc:Health()
    npc:SetHealth(1000)
    local prop = ents.Create("prop_physics")
    prop:SetPos(origin + Vector(96, -96, 24))
    prop:SetName("garrycraft-test-prop")
    prop:SetModel("models/props_junk/wood_crate001a.mdl")
    prop:Spawn()
    prop.GarryCraftTestHealth = math.max(prop:Health(), 100)
    prop:SetHealth(1000)
    prop:GetPhysicsObject():EnableMotion(false)
    targets = {npc, prop}
    if IsValid(looseProp) then looseProp:Remove() end
    looseProp = ents.Create("prop_physics")
    looseProp:SetModel("models/props_c17/oildrum001.mdl")
    looseProp:SetPos(origin + GC.DirectionToSource(7, 0.8, 4))
    looseProp:SetName("garrycraft-test-blast-prop")
    looseProp:Spawn()
    looseProp:SetHealth(10000)
    looseStart = looseProp:GetPos()
    largestImpulse = 0
    trace = {}
    started = nil
    finished = false
    phase = nil
    aiHealth = nil
    armed = false
    owner:ConCommand("garrycraft_fps_reset\n")
end

function GC.ParitySample(state)
    if state.parityRequest ~= request or finished or RealTime() < nextSample then return end
    if not started then started = RealTime() end
    nextSample = RealTime() + 0.05
    local health = {}
    if phase ~= state.parityPhase then
        phase = state.parityPhase
        if phase == "tnt-fuse" and IsValid(looseProp) then
            -- Reset the owned barrel before the blast so earlier physics cannot move it out of range.
            local physics = looseProp:GetPhysicsObject()
            looseProp:SetPos(testOrigin + GC.DirectionToSource(7, 0.8, 4))
            physics:SetVelocity(Vector(0, 0, 0))
            physics:Wake()
            looseStart = looseProp:GetPos()
        end
        if phase == "mob-combat" and IsValid(targets[1]) then
            targets[1]:SetPos(testOrigin + GC.DirectionToSource(4, 0, -3))
            targets[1]:SetMoveType(MOVETYPE_NONE)
            targets[1]:CapabilitiesRemove(CAP_MOVE_GROUND)
            targets[1]:SetSchedule(SCHED_NPC_FREEZE)
            targets[1]:SetVelocity(-targets[1]:GetVelocity())
            targets[1]:SetHealth(3000)
            aiHealth = 3000
            targets[1]:AddFlags(FL_FROZEN)
        end
    end
    -- Let the monster reach and strike a stationary citizen before checking Source return fire.
    if phase == "mob-combat" and not armed and IsValid(targets[1]) then
        targets[1]:SetPos(testOrigin + GC.DirectionToSource(4, 0, -3))
        targets[1]:SetSchedule(SCHED_NPC_FREEZE)
    end
    if phase == "mob-combat" and state.parityTick >= 1260 and not armed and IsValid(targets[1]) then
        armed = true
        targets[1]:RemoveFlags(FL_FROZEN)
        targets[1]:SetMoveType(MOVETYPE_STEP)
        targets[1]:CapabilitiesAdd(CAP_MOVE_GROUND)
        targets[1]:ClearSchedule()
        targets[1]:Give("weapon_smg1")
        targets[1]:SetNPCState(NPC_STATE_ALERT)
    end
    if phase == "tnt-explosion" and IsValid(looseProp) then largestImpulse = math.max(largestImpulse, looseProp:GetVelocity():Length()) end
    for index, entity in ipairs(targets) do health[index] = IsValid(entity) and entity:Health() or -1 end
    trace[#trace + 1] = {time = RealTime() - started, phase = state.parityPhase, health = health,
        hitAck = GC.EntitiesAck(), applied = GC.EntitiesApplied(), worldAck = GC.BlocksAck(),
        position = GC.ToMinecraft(player.GetHumans()[1]:GetPos()), reference = state.reference,
        minecraftFps = state.fps, gridHeight = GC.GridHeight, blockEntities = #ents.FindByClass("gc_block"),
        npcPosition = IsValid(targets[1]) and GC.ToMinecraft(targets[1]:GetPos()) or {},
        npcEnemy = IsValid(targets[1]) and IsValid(targets[1]:GetEnemy()) and targets[1]:GetEnemy():GetClass() or "",
        mobDamageAck = state.mobDamageAck, mobs = state.mobs}
    if state.parityPhase == "done" or RealTime() - started > 120 then
        finished = true
        file.Write("garrycraft-parity-source.json", util.TableToJSON({request = request, trace = trace, finalHealth = health,
            applied = GC.EntitiesApplied(), completed = state.parityPhase == "done",
            blastSpeed = largestImpulse, blastDisplacement = IsValid(looseProp) and looseProp:GetPos():Distance(looseStart) or -1,
            aiDamage = aiHealth and aiHealth - health[1] or 0, mobScans = GC.MobScanReport()}))
        print("GarryCraft parity trace saved")
        player.GetHumans()[1]:ConCommand("garrycraft_render_report\ngarrycraft_world_report\ngarrycraft_blocks_report\ngarrycraft_frame_report\n")
        GC.ParityStop()
    end
end
