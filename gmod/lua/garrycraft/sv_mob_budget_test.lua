local GC = GarryCraft
local test
local npcs = {}
local testOwner, wasNoTarget

local function cleanup()
    for _, npc in ipairs(npcs) do if IsValid(npc) then npc:Remove() end end
    npcs = {}
    if IsValid(testOwner) and not wasNoTarget then testOwner:RemoveFlags(FL_NOTARGET) end
    testOwner = nil
end

function GC.MobBudgetStop() cleanup() test = nil end

concommand.Add("garrycraft_test_mob_budget", function(caller)
    GC.RunEntityTest(caller)
    test = {spawned = false, samples = {}, maximumPairs = 0, maximumTraces = 0, maximumPending = 0, maximumTargeted = 0}
end)

concommand.Add("garrycraft_test_mob_cleanup", function()
    local budget = util.JSONToTable(file.Read("garrycraft-mob-budget.json", "DATA"))
    GC.Stop()
    timer.Simple(.1, function()
        local bullseyes = 0
        for _, target in ipairs(ents.FindByClass("npc_bullseye")) do
            if target.GarryCraftMob then bullseyes = bullseyes + 1 end
        end
        file.Write("garrycraft-mob-cleanup.json", util.TableToJSON({request = budget.request, bullseyes = bullseyes,
            testNpcs = #ents.FindByName("garrycraft-budget-npc")}))
    end)
end)

-- Real Source NPCs select the entity scenario's real Minecraft cows through the complete bridge.
function GC.MobBudgetSample(owner, state)
    if not test then return end
    if state.parityPhase == "fifteen-cows" and not test.spawned then
        test.spawned, test.request = true, state.parityRequest
        testOwner, wasNoTarget = owner, bit.band(owner:GetFlags(), FL_NOTARGET) ~= 0
        owner:AddFlags(FL_NOTARGET)
        for i = 0, 23 do
            local npc = ents.Create("npc_citizen")
            npc:SetName("garrycraft-budget-npc")
            npc:SetModel("models/Humans/Group01/male_07.mdl")
            npc:SetKeyValue("spawnflags", "1048576")
            npc:SetPos(owner:GetPos() + GC.DirectionToSource(i % 6 - 3, 0, -4 - math.floor(i / 6)))
            npc:Spawn()
            npc:SetSolid(SOLID_NONE)
            npc:SetMoveType(MOVETYPE_NONE)
            npc:CapabilitiesRemove(CAP_MOVE_GROUND)
            npc:SetSchedule(SCHED_NPC_FREEZE)
            npc:AddFlags(FL_FROZEN)
            npc:AddEntityRelationship(owner, D_HT, 99)
            npcs[#npcs + 1] = npc
        end
    end
    if not test.spawned then return end
    if state.parityPhase ~= "fifteen-cows" or state.parityRequest ~= test.request then
        local finished = test
        test = nil
        cleanup()
        -- Source queues entity removal until the frame ends.
        timer.Simple(.1, function()
            finished.remainingNpcs = #ents.FindByName("garrycraft-budget-npc")
            finished.passed = finished.candidatePairs >= 360 and finished.maximumPairs <= 32 and finished.maximumTraces <= 12
                and finished.maximumPending > 0 and finished.scanCompleted and finished.targetedNpcs == 24 and finished.remainingNpcs == 0
            file.Write("garrycraft-mob-budget.json", util.TableToJSON(finished))
            print("GarryCraft mob budget: " .. tostring(finished.passed))
        end)
        return
    end
    if test.tick == state.tick then return end
    test.tick = state.tick
    local scans, targeted, everTargeted = GC.MobScanReport(), 0, 0
    for _, npc in ipairs(npcs) do
        local enemy = npc:GetEnemy()
        if IsValid(enemy) and enemy.GarryCraftMob then targeted = targeted + 1 npc.GarryCraftBudgetTargeted = true end
        if npc.GarryCraftBudgetTargeted then everTargeted = everTargeted + 1 end
    end
    test.candidatePairs = 24 * table.Count(state.mobs)
    test.maximumPairs = scans.maximumPairs
    test.maximumTraces = scans.maximumTraces
    test.maximumPending = math.max(test.maximumPending, scans.pendingPairs or 0)
    test.maximumTargeted = math.max(test.maximumTargeted, targeted)
    test.targetedNpcs = everTargeted
    if test.maximumPending > 0 and scans.pendingPairs == 0 then test.scanCompleted = true end
    test.samples[#test.samples + 1] = {tick = state.tick, pendingPairs = scans.pendingPairs, targeted = targeted}
end
