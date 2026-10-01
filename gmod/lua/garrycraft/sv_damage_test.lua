local GC = GarryCraft
local request, npc, enemy, phase
local trace = {}
local expected

function GC.DamageTestStop()
    GC.RestoreDamageSettings()
    if IsValid(npc) then npc:Remove() end
    if IsValid(enemy) then enemy:Remove() end
    request = nil
end

function GC.RunDamageTest(caller)
    assert(game.SinglePlayer(), "Damage tests require local single-player")
    GC.DamageTestStop()
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    local nextRequest = "damage:" .. tostring(SysTime())
    GC.BeginTest(owner, nextRequest)
    request = nextRequest
    GC.DamageTestSettings(2)
    expected = {playerDamage = 7 * GC.DamageScale("units") * GC.DamageScale("playerToSource"),
        mobDamage = 3 * GC.DamageScale("units") * GC.DamageScale("mobToSource"),
        sourcePlayer = 10 * GC.DamageScale("sourceToPlayer"), sourceMob = 10 * GC.DamageScale("sourceToMob")}
    npc = ents.Create("npc_citizen")
    npc:SetPos(owner:GetPos() + Vector(0, -96, 0))
    npc:SetModel("models/Humans/Group01/male_07.mdl")
    npc:SetName("garrycraft-scaling-npc")
    npc:Spawn()
    npc:SetHealth(10000)
    npc:SetSchedule(SCHED_NPC_FREEZE)
    enemy = ents.Create("npc_combine_s")
    enemy:SetName("garrycraft-scaling-attacker")
    enemy:SetPos(owner:GetPos() + Vector(8192, 0, 0))
    enemy:Spawn()
    enemy:SetMoveType(MOVETYPE_NONE)
    enemy:SetHealth(10000)
    enemy:SetSchedule(SCHED_NPC_FREEZE)
    phase = nil
    trace = {}
end

function GC.DamageTestSample(owner, state)
    if not request or state.damageTestRequest ~= request then return end
    trace[#trace + 1] = {phase = state.damageTestPhase, npcHealth = npc:Health(), playerHealth = state.health, applied = GC.EntitiesApplied(),
        sourceDamage = GC.DamageTotal(), damageAck = state.damageAck, gameMode = state.gameMode, god = owner:HasGodMode()}
    if state.damageTestPhase == phase then return end
    phase = state.damageTestPhase
    if phase == "source-player" or phase == "source-mob" then
        local target = phase == "source-player" and owner or GC.MobTarget(state.damageTestMob)
        if not IsValid(target) then error("Damage scenario target is not available") end
        local hit = DamageInfo()
        hit:SetDamage(10)
        -- Citizens cannot hurt their friendly player in Source. Use a hostile native attacker for that direction.
        hit:SetAttacker(phase == "source-player" and enemy or npc)
        hit:SetDamageType(DMG_BULLET)
        target:TakeDamageInfo(hit)
    elseif phase == "done" then
        file.Write("garrycraft-damage-source.json", util.TableToJSON({request = request, expected = expected, trace = trace}))
        GC.DamageTestStop()
    end
end
hook.Add("ShutDown", "GarryCraftDamageTestCleanup", GC.DamageTestStop)
