-- Load in both realms of an owned single-player lab. Drive controls through Windows input.
-- This fixture observes native controls. It never changes a CUserCmd or calls gun actions.
assert(game.SinglePlayer(), "The physgun fixture requires single-player")
local GC = GarryCraft
if CLIENT then
    local phase, nextWrite = "", 0
    local viewmodels, beams = 0, 0
    local viewmodelFrames = {}
    hook.Add("PostDrawViewModel", "GarryCraftPhysgunNativeProbe", function(model, player)
        if player ~= LocalPlayer() or not player:GetNWBool("GarryCraftPhysgunTest") then return end
        viewmodels = viewmodels + 1
        if (phase == "walk-viewmodel" or phase == "jump-viewmodel") and #viewmodelFrames < 800 then
            local camera = player:GetNWBool("GarryCraft") and GC.ViewOrigin or EyePos()
            local look = player:GetNWBool("GarryCraft") and GC.ViewAngles or EyeAngles()
            local offset = WorldToLocal(model:GetPos(), model:GetAngles(), camera, look)
            viewmodelFrames[#viewmodelFrames + 1] = {phase = phase, time = RealTime(), frameTime = RealFrameTime(),
                offset = {offset.x, offset.y, offset.z}, camera = {camera.x, camera.y, camera.z}}
        end
    end)
    hook.Add("DrawPhysgunBeam", "GarryCraftPhysgunNativeProbe", function(player, _, enabled)
        if player == LocalPlayer() and player:GetNWBool("GarryCraftPhysgunTest") and enabled then beams = beams + 1 end
    end)
    hook.Add("Think", "GarryCraftPhysgunNativeProbe", function()
        local player = LocalPlayer()
        if not IsValid(player) or not player:GetNWBool("GarryCraftPhysgunTest") then return end
        local step = player:GetNWString("GarryCraftPhysgunTestStep")
        if step ~= phase then
            phase = step
            viewmodels, beams = 0, 0
        end
        if RealTime() < nextWrite then return end
        nextWrite = RealTime() + .05
        local state = GC.State
        file.Write("garrycraft-physgun-client.json", util.TableToJSON({step = step,
            mode = player:GetNWString("GarryCraftPhysgunTestMode"),
            screenOpen = state and state.screenOpen or false, equipped = state and state.physgunEquipped or false,
            slot = GC.SelectedSlot or 0, viewmodels = viewmodels, beams = beams,
            weaponSelectionAllowed = hook.Run("HUDShouldDraw", "CHudWeaponSelection") ~= false,
            viewmodelFrames = viewmodelFrames,
            useBinding = input.LookupBinding("+use"), eye = {EyePos().x, EyePos().y, EyePos().z}}))
    end)
    return
end
if GC.PhysgunNativeTest then GC.PhysgunNativeTest.Finish("reloaded") end

local test = {}
GC.PhysgunNativeTest = test
local owner, run, fixture
local props, owned = {}, {}
local held
local step = "initial"
local nextSample = 0
local hookName = "GarryCraftPhysgunNativeTest"
local modes = {source = true, minecraft = true}
local convars = {"gm_snapangles", "physgun_rotation_sensitivity", "physgun_wheelspeed", "physgun_maxrange",
    "physgun_maxSpeed", "physgun_maxAngular", "physgun_timeToArrive", "physgun_timeToArriveRagdoll"}

local function vector(value) return {value.x, value.y, value.z} end
local function angles(value) return {value.p, value.y, value.r} end
local function weapon()
    local current = owner:GetActiveWeapon()
    return IsValid(current) and current:GetClass() or ""
end

local function save()
    file.Write("garrycraft-physgun-" .. run.mode .. ".json", util.TableToJSON(run, true))
end

local function physics(entity)
    if not IsValid(entity) then return {valid = false} end
    local body = entity:GetPhysicsObject()
    return {valid = true, id = entity:EntIndex(), creation = entity:GetCreationID(),
        position = vector(entity:GetPos()), angles = angles(entity:GetAngles()),
        velocity = vector(body:GetVelocity()), angularVelocity = vector(body:GetAngleVelocity()),
        motion = body:IsMotionEnabled(), asleep = body:IsAsleep(), gravity = body:IsGravityEnabled(),
        heldByPlayer = entity:IsPlayerHolding(), eyeDistance = entity:GetPos():Distance(owner:GetShootPos())}
end

local function sample()
    local entities = {}
    for name, entity in pairs(props) do entities[name] = physics(entity) end
    local mirror = owner:GetNWEntity("GarryCraftPhysgunHeld")
    local trace = owner:GetEyeTrace()
    return {time = RealTime() - run.started, step = step, weapon = weapon(),
        bridge = owner:GetNWBool("GarryCraft"), nativeGun = owner:GetNWBool("GarryCraftPhysgun"),
        playerPosition = vector(owner:GetPos()), eye = vector(owner:GetShootPos()), aim = angles(owner:EyeAngles()),
        held = IsValid(held) and held:EntIndex() or -1,
        heldMirror = IsValid(mirror) and mirror:EntIndex() or -1,
        client = util.JSONToTable(file.Read("garrycraft-physgun-client.json", "DATA") or "{}"),
        trace = {hit = trace.Hit, hitNonWorld = trace.HitNonWorld, entity = IsValid(trace.Entity) and trace.Entity:EntIndex() or -1,
            position = vector(trace.HitPos), bone = trace.PhysicsBone}, entities = entities}
end

local function event(name, entity, details)
    if not run then return end
    run.events[#run.events + 1] = {time = RealTime() - run.started, step = step, name = name,
        entity = IsValid(entity) and entity:EntIndex() or -1, details = details}
end

local function spawn(name, position)
    local entity = ents.Create("prop_physics")
    entity:SetModel("models/props_junk/wood_crate001a.mdl")
    entity:SetPos(position)
    entity:SetAngles(Angle(0, 0, 0))
    entity:SetName("garrycraft-physgun-test-" .. name)
    entity:Spawn()
    entity:SetCreator(owner)
    local body = entity:GetPhysicsObject()
    assert(IsValid(body), "The installed crate model must expose native physics")
    body:EnableGravity(false)
    body:EnableMotion(true)
    body:Wake()
    props[name] = entity
    owned[#owned + 1] = entity
    return entity
end

function test.Snapshot(label)
    assert(run and IsValid(owner), "Snapshot requires an active fixture and a valid player")
    local row = sample()
    row.label = label or step
    run.snapshots[#run.snapshots + 1] = row
    save()
    return row
end

function test.Mark(label)
    assert(run and type(label) == "string", "Mark requires an active fixture and a step name")
    step = label
    owner:SetNWString("GarryCraftPhysgunTestStep", step)
    event("mark", nil)
    return test.Snapshot(label)
end

function test.Finish(reason)
    if not run then return end
    if IsValid(owner) then test.Snapshot("finish") end
    run.finished = true
    run.reason = reason or "complete"
    run.duration = RealTime() - run.started
    save()
    if IsValid(owner) then owner:SetNWBool("GarryCraftPhysgunTest", false) end
    hook.Remove("StartCommand", hookName)
    hook.Remove("Think", hookName)
    hook.Remove("OnPhysgunPickup", hookName)
    hook.Remove("PhysgunDrop", hookName)
    hook.Remove("OnPhysgunFreeze", hookName)
    hook.Remove("PlayerUnfrozeObject", hookName)
    hook.Remove("OnPhysgunReload", hookName)
    -- Removing an owned held body lets the installed weapon perform its own release.
    for _, entity in ipairs(owned) do if IsValid(entity) then entity:Remove() end end
    props, owned = {}, {}
    held = nil
    local completed = run
    run, owner = nil, nil
    return completed
end

-- Translate only unheld fixture bodies. Leave native motion flags and frozen-object entries unchanged.
function test.Stage(name)
    assert(run and IsValid(owner), "Stage requires an active fixture")
    for _, entity in pairs(props) do assert(not entity:IsPlayerHolding(), "Release fixture bodies before staging") end
    local eye, forward, right = owner:GetShootPos(), owner:EyeAngles():Forward(), owner:EyeAngles():Right()
    local delta
    if name == "target" then
        props.target:SetPos(eye + forward * 160)
    elseif name == "pairA" or name == "pairB" then
        props.target:SetPos(eye + forward * 160 + right * 512)
        delta = eye + forward * 160 - props[name]:GetPos()
    elseif name == "away" then
        props.target:SetPos(eye + forward * 160 + right * 512)
        delta = eye + forward * 240 + right * 144 - props.pairA:GetPos()
    else error("Unknown fixture stage") end
    if delta then
        props.pairA:SetPos(props.pairA:GetPos() + delta)
        props.pairB:SetPos(props.pairB:GetPos() + delta)
    end
    event("fixture-stage", nil, {name = name})
    test.Snapshot("stage-" .. name)
end

-- Reuse the first pass's fixture geometry. Neither pass moves the player or changes aim.
function test.Begin(mode, geometry)
    assert(modes[mode], "Physgun mode must be source or minecraft")
    assert(not run, "Finish the current physgun pass first")
    owner = player.GetHumans()[1]
    assert(IsValid(owner) and owner:Alive(), "The fixture requires a living local player")
    if mode == "source" then assert(not GC.IsActive(), "Stop the bridge for the Source reference pass")
    else assert(GC.IsLinked(), "Link Minecraft for the Minecraft pass") end
    assert(weapon() == "weapon_physgun", "Select the installed native physics gun before Begin")
    fixture = geometry or fixture or {eye = vector(owner:GetShootPos()), aim = angles(owner:EyeAngles())}
    local eye = Vector(unpack(fixture.eye))
    local aim = Angle(unpack(fixture.aim))
    local forward, right = aim:Forward(), aim:Right()
    step = "initial"
    owner:SetNWBool("GarryCraftPhysgunTest", true)
    owner:SetNWString("GarryCraftPhysgunTestStep", step)
    owner:SetNWString("GarryCraftPhysgunTestMode", mode)
    nextSample = 0
    run = {mode = mode, map = game.GetMap(), started = RealTime(), fixture = fixture,
        inputDriver = "Windows keyboard and mouse", commandStage = "StartCommand observer hook, engine hook order unspecified",
        convars = {}, events = {}, commands = {}, samples = {}, snapshots = {}}
    for _, name in ipairs(convars) do run.convars[name] = GetConVar(name):GetString() end
    spawn("target", eye + forward * 160)
    local pairA = spawn("pairA", eye + forward * 240 + right * 144)
    local pairB = spawn("pairB", eye + forward * 240 + right * 208)
    local weld = constraint.Weld(pairA, pairB, 0, 0, 0, true)
    assert(IsValid(weld), "The fixture requires an installed native weld constraint")
    owned[#owned + 1] = weld

    hook.Add("StartCommand", hookName, function(player, command)
        if player ~= owner then return end
        if #run.commands >= 60000 then run.commandsTruncated = true return end
        run.commands[#run.commands + 1] = {time = RealTime() - run.started, step = step,
            number = command:CommandNumber(), buttons = command:GetButtons(), wheel = command:GetMouseWheel(),
            mouseX = command:GetMouseX(), mouseY = command:GetMouseY(), angles = angles(command:GetViewAngles()),
            forward = command:GetForwardMove(), side = command:GetSideMove(), up = command:GetUpMove(), weapon = weapon()}
    end)
    hook.Add("OnPhysgunPickup", hookName, function(player, entity)
        if player ~= owner then return end
        held = entity
        event("pickup", entity)
    end)
    hook.Add("PhysgunDrop", hookName, function(player, entity)
        if player ~= owner then return end
        event("drop", entity)
        held = nil
    end)
    hook.Add("OnPhysgunFreeze", hookName, function(_, body, entity, player)
        if player == owner then event("freeze", entity, {motionBefore = body:IsMotionEnabled()}) end
    end)
    hook.Add("PlayerUnfrozeObject", hookName, function(player, entity, body)
        if player == owner then event("unfreeze", entity, {motionAfter = body:IsMotionEnabled()}) end
    end)
    hook.Add("OnPhysgunReload", hookName, function(_, player)
        if player == owner then event("reload", nil) end
    end)
    hook.Add("Think", hookName, function()
        if RealTime() < nextSample then return end
        nextSample = RealTime() + 0.05
        if not IsValid(owner) then test.Finish("owner-lost") return end
        if #run.samples < 20000 then run.samples[#run.samples + 1] = sample()
        else run.samplesTruncated = true end
    end)
    test.Snapshot("begin")
    return fixture
end
