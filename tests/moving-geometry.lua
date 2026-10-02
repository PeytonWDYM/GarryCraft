-- Run in a fresh single-player lab session after Minecraft links.
-- Failure cases: skipped shape packets, sleeping and moving props, rebuilt physics,
-- changed bounds, disabled collision, removal, range exit, and recycled entity indices.
-- The trace compares the same public physics mesh against Minecraft's received triangles.
local GC = GarryCraft
assert(game.SinglePlayer() and GC.IsLinked(), "Moving geometry requires a linked single-player lab session")
local owner = player.GetHumans()[1]
GC.MovingGeometryTrace(true)
local prop = ents.Create("prop_physics")
prop:SetModel("models/props_c17/FurnitureTable001a.mdl")
prop:SetName("moving geometry \"table\" café 日本")
prop:SetPos(owner:GetPos() + Vector(128, 0, 64))
prop:Spawn()
prop:GetPhysicsObject():EnableMotion(false)
local npc = ents.Create("npc_zombie")
npc:SetPos(owner:GetPos() + Vector(256, 0, 64))
npc:SetName("moving geometry NPC 日本")
npc:Spawn()
npc:SetMoveType(MOVETYPE_NONE)
npc:AddFlags(FL_FROZEN)
local ownedActors = {[prop:EntIndex()] = true, [npc:EntIndex()] = true}
local records = {}
local originalSend = garrycraft_bridge.send
local dropPackets, droppedPackets = 0, 0
garrycraft_bridge.send = function(lane, payload)
    if lane == 3 and dropPackets > 0 then
        dropPackets = dropPackets - 1
        droppedPackets = droppedPackets + 1
        return
    end
    return originalSend(lane, payload)
end
local phases = {
    {name = "initial"},
    {name = "unchanged"},
    {name = "translate", run = function() prop:SetPos(prop:GetPos() + Vector(0, 96, 32)) end},
    {name = "rotate", run = function() prop:SetAngles(Angle(20, 70, 15)) end},
    {name = "physics-rebuild", run = function() prop:PhysicsInitBox(Vector(-16, -24, -8), Vector(16, 24, 8)) prop:GetPhysicsObject():EnableMotion(false) end},
    {name = "collision-disabled", run = function() prop:GetPhysicsObject():EnableCollisions(false) end},
    {name = "collision-restored", run = function() prop:GetPhysicsObject():EnableCollisions(true) end},
    {name = "range-exit", run = function() prop:SetPos(owner:GetPos() + Vector(2048, 0, 64)) end},
    {name = "range-return", run = function() prop:SetPos(owner:GetPos() + Vector(128, 0, 64)) end},
    {name = "removed", run = function() prop:Remove() end},
    {name = "replacement", run = function()
        prop = ents.Create("prop_physics")
        prop:SetModel("models/hunter/blocks/cube025x025x025.mdl")
        prop:SetPos(owner:GetPos() + Vector(128, 0, 64))
        prop:Spawn()
        prop:GetPhysicsObject():EnableMotion(false)
        ownedActors[prop:EntIndex()] = true
    end},
    {name = "skipped-shape-packets", run = function()
        prop:PhysicsInitBox(Vector(-12, -32, -8), Vector(12, 32, 8))
        prop:GetPhysicsObject():EnableMotion(false)
        dropPackets = 3
    end},
}
local index = 0
timer.Create("GarryCraftMovingGeometryTest", 1, #phases, function()
    index = index + 1
    local phase = phases[index]
    if phase.run then phase.run() end
    timer.Simple(0.3, function()
        local id = IsValid(prop) and prop:EntIndex() or records[1].entity
        local triangles = {}
        for _, triangle in ipairs(GC.DynamicGeometry(owner)) do
            if triangle[10] == id then triangles[#triangles + 1] = triangle end
        end
        local actors = {}
        for _, actor in ipairs(GC.EntityTargets(owner)) do
            if ownedActors[actor.id] then actors[#actors + 1] = actor end
        end
        local actorIds = {}
        for actorId in pairs(ownedActors) do actorIds[#actorIds + 1] = actorId end
        records[#records + 1] = {phase = phase.name, entity = id,
            creation = IsValid(prop) and prop:GetCreationID() or -1, triangles = triangles, actors = actors, actorIds = actorIds,
            source = GC.MovingGeometryStats(), minecraft = GC.MovingGeometryPeer()}
        file.Write("garrycraft-moving-geometry.json", util.TableToJSON({phases = records, droppedPackets = droppedPackets}, true))
        if index == #phases then
            GC.MovingGeometryTrace(false)
            prop:Remove()
            npc:Remove()
            garrycraft_bridge.send = originalSend
        end
    end)
end)
