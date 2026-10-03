-- Test-Performance.ps1 loads this fixture only in an owned single-player lab.
assert(game.SinglePlayer(), "Performance tests require single-player")
local GC = GarryCraft
local owner = player.GetHumans()[1]
local test = {props = {}, samples = {}, phase = "idle"}
GC.PerformanceTest = test
local geometryName = GC.DynamicGeometryPacket and "DynamicGeometryPacket" or "DynamicGeometry"
local originalGeometry = GC[geometryName]

if originalGeometry then
    GC[geometryName] = function(...)
        local started = SysTime()
        local triangles = originalGeometry(...)
        test.samples[#test.samples + 1] = {ms = (SysTime() - started) * 1000, size = #triangles,
            stages = GC.MovingGeometryStats and GC.MovingGeometryStats()}
        return triangles
    end
end

function test.Clear()
    for _, prop in ipairs(test.props) do if IsValid(prop) then prop:Remove() end end
    test.props = {}
end

-- The same active collision scene runs with and without the bridge.
function test.Begin(count, label)
    test.Clear()
    test.phase, test.samples = label, {}
    local origin = owner:GetPos()
    for index = 1, count do
        local prop = ents.Create("prop_physics")
        prop:SetModel("models/hunter/blocks/cube025x025x025.mdl")
        local angle = index * 2.3999632297
        local radius = 112 + (index % 8) * 30
        prop:SetPos(origin + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 96 + (index % 6) * 35))
        prop:SetAngles(Angle(index % 45, index * 13 % 360, 0))
        prop:Spawn()
        prop:SetName("garrycraft-performance-" .. index)
        local physics = prop:GetPhysicsObject()
        physics:EnableGravity(false)
        physics:Wake()
        prop.GarryCraftPerformanceAnchor = prop:GetPos()
        test.props[#test.props + 1] = prop
    end
end

local nextForce = 0
hook.Add("Think", "GarryCraftPerformanceFixture", function()
    if RealTime() < nextForce then return end
    nextForce = RealTime() + .05
    local time = RealTime()
    for index, prop in ipairs(test.props) do
        local physics = prop:GetPhysicsObject()
        local offset = Vector(math.sin(time * 2 + index) * 30, math.cos(time * 2 + index) * 30, math.sin(time + index) * 18)
        local delta = prop.GarryCraftPerformanceAnchor + offset - prop:GetPos()
        physics:ApplyForceCenter((delta * 8 - physics:GetVelocity() * 2) * physics:GetMass())
        physics:AddAngleVelocity(Vector(0, 0, 8))
        physics:Wake()
    end
end)

function test.Report()
    local awake = 0
    for _, prop in ipairs(test.props) do if not prop:GetPhysicsObject():IsAsleep() then awake = awake + 1 end end
    file.Write("garrycraft-performance.json", util.TableToJSON({phase = test.phase, props = #test.props,
        awake = awake, linked = GC.IsLinked(), geometry = test.samples, backend = geometryName,
        nativeGeometry = GC.MovingGeometryStats and GC.MovingGeometryStats()}))
end

function test.Stop()
    test.Clear()
    hook.Remove("Think", "GarryCraftPerformanceFixture")
    if originalGeometry then GC[geometryName] = originalGeometry end
    GC.PerformanceTest = nil
end
