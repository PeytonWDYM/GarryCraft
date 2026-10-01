local GC = GarryCraft
require("garrycraft")

util.AddNetworkString("garrycraft_slot")
util.AddNetworkString("garrycraft_sprint")
util.AddNetworkString("garrycraft_texture_ack")
util.AddNetworkString("garrycraft_render_reset")
util.AddNetworkString("garrycraft_controls")
util.AddNetworkString("garrycraft_fps")
util.AddNetworkString("garrycraft_ui_event")
local sprintHeld = false
local owner
local session
local frame = 0
local lastPeer = 0
local lastFrame = -1
local peerInstance
local renderInstance
local nextSend = 0
local batches = {}
local batchIndex = 1
local input = {}
local pose
local saved
local testId = ""
local uiEvents = {}
local uiSequence = 0

local bridgePath = CreateConVar("garrycraft_bridge", "", FCVAR_ARCHIVE, "Absolute path to GarryCraft bridge.bin")

local function stop()
    GC.DamageTestStop()
    GC.RespawnStop()
    GC.DamageStop()
    GC.BlocksStop()
    GC.MobsStop()
    if IsValid(owner) then
        owner:SetNWBool("GarryCraft", false)
        owner:SetMoveType(saved.moveType)
        owner:SetHull(saved.hullMin, saved.hullMax)
        owner:SetHullDuck(saved.duckMin, saved.duckMax)
        owner:SetViewOffset(saved.eye)
        owner:SetViewOffsetDucked(saved.duckEye)
        owner:SetCollisionGroup(saved.collisionGroup)
        owner:SelectWeapon(saved.weapon)
        owner:ChatPrint("GarryCraft stopped")
    end
    if session then
        garrycraft_bridge.send(0, util.TableToJSON({version = 1, session = session, active = false, frame = frame}))
    end
    owner = nil
    pose = nil
end

local function start(player)
    if not game.SinglePlayer() then error("GarryCraft currently supports local single-player only") end
    if IsValid(owner) then stop() end
    local path = bridgePath:GetString()
    if path == "" then error("Set garrycraft_bridge to the absolute path of bridge.bin") end
    garrycraft_bridge.open(path)
    GC.AlignGrid(player)
    batches = GC.StaticGeometry()
    owner = player
    session = game.GetMap() .. ":" .. tostring(SysTime())
    GC.EntitiesBegin(session)
    GC.MobsBegin(player)
    GC.BlocksBegin(player, session)
    batchIndex = 1
    lastPeer = RealTime()
    lastFrame = -1
    peerInstance = nil
    renderInstance = nil
    input = {slot = 0, targetFps = garrycraft_bridge.refresh(), renderEpoch = 0}
    testId = ""
    sprintHeld = false
    uiEvents = {}
    uiSequence = 0
    local hullMin, hullMax = player:GetHull()
    local duckMin, duckMax = player:GetHullDuck()
    saved = {moveType = player:GetMoveType(), hullMin = hullMin, hullMax = hullMax,
        duckMin = duckMin, duckMax = duckMax, eye = player:GetViewOffset(),
        duckEye = player:GetViewOffsetDucked(), collisionGroup = player:GetCollisionGroup(),
        weapon = IsValid(player:GetActiveWeapon()) and player:GetActiveWeapon():GetClass() or "weapon_physgun"}
    player:Give("weapon_garrycraft")
    player:SelectWeapon("weapon_garrycraft")
    player:SetHull(Vector(-9.6, -9.6, 0), Vector(9.6, 9.6, 57.6))
    player:SetHullDuck(Vector(-9.6, -9.6, 0), Vector(9.6, 9.6, 48))
    player:SetNWString("GarryCraftBridge", path)
    player:SetNWString("GarryCraftSession", session)
    player:SetNWBool("GarryCraft", true)
    GC.RespawnBegin(player)
    GC.DamageBegin(player)
    player:ChatPrint("GarryCraft: waiting for Minecraft")
end

function GC.BeginTest(player, id)
    start(player)
    testId = id
end

GC.Start = start
GC.Stop = stop

concommand.Add("garrycraft_start", function(caller)
    if IsValid(caller) then start(caller) else
        timer.Create("GarryCraftStart", 1, 30, function()
            local localPlayer = player.GetHumans()[1]
            if IsValid(localPlayer) then timer.Remove("GarryCraftStart") start(localPlayer) end
        end)
    end
end)
concommand.Add("garrycraft_stop", stop)

net.Receive("garrycraft_slot", function(_, player)
    if player == owner then input.slot = math.Clamp(net.ReadUInt(4), 0, 8) end
end)

net.Receive("garrycraft_sprint", function(_, player)
    if player == owner then sprintHeld = net.ReadBool() end
end)

net.Receive("garrycraft_texture_ack", function(_, player)
    local ack = net.ReadUInt(24)
    local process = net.ReadString()
    if player == owner and process == renderInstance then
        input.textureAck = math.max(input.textureAck or 0, ack)
        input.textureInstance = process
    end
end)
net.Receive("garrycraft_render_reset", function(_, player)
    if player == owner then input.renderEpoch = input.renderEpoch + 1 end
end)

net.Receive("garrycraft_fps", function(_, player)
    if player == owner then input.targetFps = math.Clamp(net.ReadUInt(16), 10, 1000) end
end)

net.Receive("garrycraft_ui_event", function(_, player)
    if player ~= owner then return end
    uiSequence = uiSequence + 1
    uiEvents[#uiEvents + 1] = {id = uiSequence, key = net.ReadUInt(9), text = net.ReadString()}
end)

net.Receive("garrycraft_controls", function(_, player)
    if player ~= owner then return end
    input.camera = net.ReadBool()
    input.inventory = net.ReadBool()
    input.escape = net.ReadBool()
    input.chat = net.ReadBool()
    input.mouseX, input.mouseY = net.ReadFloat(), net.ReadFloat()
    input.uiAttack, input.uiUse = net.ReadBool(), net.ReadBool()
    input.viewportWidth, input.viewportHeight = net.ReadUInt(13), net.ReadUInt(13)
end)

hook.Add("StartCommand", "GarryCraftInput", function(player, command)
    if player ~= owner then return end
    input.forward = command:KeyDown(IN_FORWARD)
    input.back = command:KeyDown(IN_BACK)
    input.left = command:KeyDown(IN_MOVELEFT)
    input.right = command:KeyDown(IN_MOVERIGHT)
    input.jump = command:KeyDown(IN_JUMP)
    input.sneak = command:KeyDown(IN_DUCK)
    input.sprint = sprintHeld or command:KeyDown(IN_SPEED)
    input.attack = pose and pose.screenOpen and input.uiAttack or command:KeyDown(IN_ATTACK)
    input.use = pose and pose.screenOpen and input.uiUse or command:KeyDown(IN_ATTACK2)
    input.yaw = -command:GetViewAngles().y - 90
    input.pitch = command:GetViewAngles().p
    command:ClearMovement()
    command:RemoveKey(IN_ATTACK)
    command:RemoveKey(IN_ATTACK2)
end)

hook.Add("Move", "GarryCraftMovement", function(player, movement)
    if player ~= owner then return end
    local target, sequence = GC.RespawnTarget()
    if not player:Alive() then return end
    if not pose or pose.teleportAck ~= sequence then
        movement:SetOrigin(target)
        movement:SetVelocity(vector_origin)
        return true
    end
    movement:SetOrigin(pose and GC.ToSource(pose.x, pose.y, pose.z) or player:GetPos())
    movement:SetVelocity(vector_origin)
    return true
end)

hook.Add("Think", "GarryCraftBridge", function()
    if not IsValid(owner) then return end
    local payload = garrycraft_bridge.receive(1)
    if payload then
        local state = util.JSONToTable(payload)
        if state.version == 1 and state.session == session and state.instance ~= peerInstance then
            if peerInstance then
                GC.RespawnNewPeer()
                GC.DamageBegin(owner)
                GC.MobsBegin(owner)
                GC.EntitiesBegin(session)
                GC.BlocksBegin(owner, session)
                uiEvents = {}
                uiSequence = 0
            end
            peerInstance = state.instance
            lastFrame = -1
            batchIndex = 1
        end
        if state.version == 1 and state.session == session and state.frame > lastFrame then
            if renderInstance ~= state.renderInstance then
                input.textureAck = 0
                input.textureInstance = state.renderInstance
            end
            renderInstance = state.renderInstance
            if state.uiAck then while uiEvents[1] and uiEvents[1].id <= state.uiAck do table.remove(uiEvents, 1) end end
            if state.damageAck then GC.DamageAcknowledge(state.damageAck) end
            GC.EntitiesHit(owner, state)
            GC.MobsAccept(state)
            GC.ParitySample(state)
            GC.DamageTestSample(owner, state)
            GC.TerrainTestSample(owner, state)
            if state.lightingTestPhase and state.lightingTestPhase ~= "done" and state.lightingTestRequest == testId then
                owner:SetEyeAngles(Angle(state.lightingTestPitch, -state.lightingTestYaw - 90, 0))
            end
            lastFrame = state.frame
            lastPeer = RealTime()
            if state.geometryAck == batchIndex - 1 then batchIndex = batchIndex + 1 end
            if state.linked and not state.reference and GC.RespawnAccept(state) then
                pose = state
                owner:SetPos(GC.ToSource(state.x, state.y, state.z))
                owner:SetViewOffset(Vector(0, 0, state.eye * 32))
                owner:SetNWFloat("GarryCraftEye", state.eye * 32)
                GC.LabCase(state.fixture or "")
                owner:SetHull(Vector(-9.6, -9.6, 0), Vector(9.6, 9.6, state.height * 32))
                if state.health > 0 then owner:SetHealth(math.ceil(state.health * 5)) end
            end
        end
    end
    if peerInstance and RealTime() - lastPeer > 5 then stop() return end
    frame = frame + 1
    GC.BlocksPoll(renderInstance)
    local position = GC.ToMinecraft(owner:GetPos())
    local target, sequence = GC.RespawnTarget()
    if not pose or pose.teleportAck ~= sequence then position = GC.ToMinecraft(target) end
    input.version = 1
    input.session = session
    input.frame = frame
    input.geometryBatches = #batches
    input.test = testId
    input.active = true
    input.teleportSeq = sequence
    input.damageTotal = GC.DamageTotal()
    input.damageEvents = GC.DamageEvents()
    input.damageScaling = GC.MinecraftDamageSettings()
    input.entityHitAck = GC.EntitiesAck()
    input.worldAck = GC.BlocksAck()
    input.worldInstance = GC.BlocksInstance()
    input.mobDamage = GC.MobDamage()
    input.uiEvents = uiEvents
    input.x, input.y, input.z = position[1], position[2], position[3]
    garrycraft_bridge.send(0, util.TableToJSON(input))
    if RealTime() < nextSend then return end
    nextSend = RealTime() + 0.05
    if batches[batchIndex] then
        garrycraft_bridge.send(2, util.TableToJSON({session = session, batch = batchIndex - 1,
            triangles = batches[batchIndex]}))
    end
    garrycraft_bridge.send(3, util.TableToJSON({session = session, triangles = GC.DynamicGeometry(owner),
        water = GC.WaterGrid(owner), actors = GC.EntityTargets(owner)}))
end)

hook.Add("ShutDown", "GarryCraftStop", stop)
