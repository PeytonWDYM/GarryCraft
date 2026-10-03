local GC = GarryCraft
local owner, session, renderInstance, epoch
local sequence = 0
local primary = false
local request
local bodies = {}
local spawned = {}
local conflicts = ""
local target
local ready = {}
local lastTrace
local mining
local miningAllowed = false
local miningError = ""
local miningPrimary = false
local miningPress = 0
util.AddNetworkString("garrycraft_physics_block_ready")

local function clear()
    if IsValid(owner) then owner:DropObject() end
    for _, body in pairs(bodies) do if IsValid(body) then body:Remove() end end
    bodies = {}
    spawned = {}
    request = nil
    primary = false
    target = nil
    ready = {}
    lastTrace = nil
    mining = nil
    miningAllowed = false
    miningError = ""
    miningPrimary = false
    miningPress = 0
end

function GC.PhysicsBlocksBegin(player, nextSession)
    clear()
    owner, session, renderInstance, epoch = player, nextSession, nil, nil
    sequence = 0
    conflicts = ""
end

function GC.PhysicsBlocksStop()
    clear()
    owner, session, renderInstance, epoch = nil, nil, nil, nil
end

-- A section stays fixed. A fresh primary press requests its one selected Minecraft cell.
function GC.PhysicsBlocksCommand(player, command, enabled)
    local attack = enabled and command:KeyDown(IN_ATTACK)
    if player ~= owner then return end
    mining = nil
    local miningAttack = not enabled and miningAllowed and command:KeyDown(IN_ATTACK)
    if miningAttack and not miningPrimary then miningPress = miningPress + 1 end
    miningPrimary = miningAttack
    if not enabled and miningAllowed then
        local hit = player:GetEyeTrace()
        local body = hit.Entity
        if IsValid(body) and body:GetClass() == "gc_physics_block" and body:GetBlockSession() == session then
            local center, point = GC.ToMinecraft(body:GetPos()), GC.ToMinecraft(hit.HitPos)
            mining = {id = body:GetBlockId(), x = center[1], y = center[2], z = center[3],
                hx = point[1], hy = point[2], hz = point[3], attack = command:KeyDown(IN_ATTACK), press = miningPress}
        end
    end
    if attack and not primary and not request and renderInstance then
        local trace = player:GetEyeTrace()
        local maximum = GetConVar("physgun_maxrange"):GetFloat()
        local eye = player:EyePos()
        local position
        local route
        local targetPoint = target and GC.ToSource(target.hx, target.hy, target.hz)
        if targetPoint and eye:DistToSqr(targetPoint) <= maximum * maximum
            and player:GetAimVector():Dot((targetPoint - eye):GetNormalized()) > .999
            and eye:DistToSqr(targetPoint) <= eye:DistToSqr(trace.HitPos) + .1 then
            position = {target.x, target.y, target.z}
            route = "minecraft"
        elseif IsValid(trace.Entity) and trace.Entity:GetClass() == "gc_block" and eye:DistToSqr(trace.HitPos) <= maximum * maximum then
            -- VPhysics reports this face .03125 units outside the voxel in the owned trace.
            -- A .125-unit inset crosses that skin and remains below Minecraft's one-pixel shapes.
            position = GC.ToMinecraft(trace.HitPos - trace.HitNormal * .125)
            route = "source"
        end
        lastTrace = {eye = eye, hit = trace.HitPos, normal = trace.HitNormal, gridHeight = GC.GridHeight,
            sourceClass = IsValid(trace.Entity) and trace.Entity:GetClass() or "", maximum = maximum,
            target = target, route = route, coordinates = position}
        if position and not IsValid(player:GetNWEntity("GarryCraftPhysgunHeld")) then
            sequence = sequence + 1
            request = {id = sequence, instance = renderInstance,
                x = math.floor(position[1]), y = math.floor(position[2]), z = math.floor(position[3])}
        end
    end
    primary = attack
end

function GC.PhysicsBlockMiningInput() return mining end

function GC.PhysicsBlockRequests()
    return request and {request} or {}
end

net.Receive("garrycraft_physics_block_ready", function(_, player)
    local id = net.ReadUInt(32)
    local packetSession, instance = net.ReadString(), net.ReadString()
    if player == owner and packetSession == session and instance == renderInstance then ready[id] = instance end
end)

local function spawn(result)
    local convexes = {}
    for _, box in ipairs(result.boxes) do
        local corners = {}
        for _, x in ipairs({box[1], box[4]}) do
            for _, y in ipairs({box[2], box[5]}) do
                for _, z in ipairs({box[3], box[6]}) do
                    corners[#corners + 1] = GC.DirectionToSource(x, y, z)
                end
            end
        end
        convexes[#convexes + 1] = corners
    end
    local body = ents.Create("gc_physics_block")
    body:SetPos(GC.ToSource(result.x + .5, result.y + .5, result.z + .5))
    body:SetBlockId(result.id)
    body:SetBlockSession(session)
    body.Convexes = convexes
    body:Spawn()
    body:SetCreator(owner)
    bodies[result.id] = body
    spawned[result.id] = true
end

function GC.PhysicsBlocksAccept(state)
    if state.physicsBlockEpoch ~= epoch then clear() epoch = state.physicsBlockEpoch end
    if renderInstance ~= state.renderInstance then ready = {} end
    renderInstance = state.renderInstance
    target = state.physicsBlockTarget
    miningAllowed = state.linked and not state.screenOpen and not state.physgunEquipped and state.health > 0 and owner:Alive()
    for _, id in ipairs(state.physicsBlockConsumed or {}) do
        if IsValid(bodies[id]) then bodies[id]:Remove() end
        bodies[id] = nil
        spawned[id] = true
    end
    local error = state.physicsBlockMining and state.physicsBlockMining.error or ""
    if error ~= miningError then
        miningError = error
        if error ~= "" then owner:ChatPrint("GarryCraft block mining: " .. error) end
    end
    local notice = table.concat(state.physicsBlockConflicts or {}, "\n")
    if notice ~= conflicts then
        conflicts = notice
        if notice ~= "" then
            owner:ChatPrint("GarryCraft could not restore these detached blocks:")
            for _, conflict in ipairs(state.physicsBlockConflicts) do owner:ChatPrint(conflict) end
        end
    end
    for _, result in ipairs(state.blockPickResults or {}) do
        if result.status == "detached" and not spawned[result.id] and result.instance == renderInstance
            and ready[result.id] == renderInstance
            and result.worldSequence > 0 and GC.BlocksInstance() == renderInstance and GC.BlocksAck() >= result.worldSequence then
            spawn(result)
        end
        if request and result.id == request.id and (result.status == "rejected" or IsValid(bodies[result.id])) then
            if result.status == "rejected" then owner:ChatPrint("GarryCraft block pickup: " .. result.error) end
            request = nil
        end
    end
end

function GC.PhysicsBlocksReport()
    local output = {request = request, epoch = epoch, lastTrace = lastTrace, mining = mining, bodies = {}}
    for id, body in pairs(bodies) do
        if IsValid(body) then
            local physics = body:GetPhysicsObject()
            output.bodies[#output.bodies + 1] = {id = id, entity = body:EntIndex(), creation = body:GetCreationID(),
                position = body:GetPos(), angles = body:GetAngles(), motion = physics:IsMotionEnabled(), held = body:IsPlayerHolding()}
        end
    end
    return output
end

hook.Add("ShutDown", "GarryCraftPhysicsBlocks", clear)
