local GC = GarryCraft
local floor
local obstacle
local currentCase

local function surface(minimum, maximum, ramp)
    local entity = ents.Create("gc_fixture")
    entity:SetPos(GC.LabOrigin + GC.ToSource(-0.5, 0, -0.5))
    entity:SetNWVector("Minimum", minimum)
    entity:SetNWVector("Maximum", maximum)
    entity:SetNWBool("Ramp", ramp or false)
    entity:Spawn()
    return entity
end

function GC.LabCase(name)
    if name == currentCase then return end
    currentCase = name
    if IsValid(obstacle) then obstacle:Remove() end
    if name == "wall" or name == "diagonal-wall" then obstacle = surface(Vector(-96, -288, 0), Vector(160, -256, 160)) end
    if name == "ceiling" then obstacle = surface(Vector(-128, -160, 64), Vector(160, 128, 96)) end
    if name == "step" then obstacle = surface(Vector(-96, -288, 0), Vector(160, -256, 16)) end
end

function GC.RunLabTest(caller)
    assert(game.SinglePlayer(), "GarryCraft tests require a local single-player map")
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    if IsValid(floor) then floor:Remove() end
    GC.LabOrigin = owner:GetPos()
    floor = surface(Vector(-256, -1568, -32), Vector(1312, 256, 0))
    floor:SetNWBool("GarryCraftStatic", true)
    owner:SetEyeAngles(Angle(0, -90, 0))
    GC.BeginTest(owner, tostring(SysTime()))
end
concommand.Add("garrycraft_test", GC.RunLabTest)

-- The agent can request a test without taking the user's keyboard or mouse.
local nextControl = 0
hook.Add("Think", "GarryCraftLabControl", function()
    if not game.SinglePlayer() or RealTime() < nextControl then return end
    nextControl = RealTime() + 0.5
    local contents = file.Read("garrycraft-control.json", "DATA")
    if not contents then return end
    local request = util.JSONToTable(contents)
    if request.id == GC.ControlRequest or not IsValid(player.GetHumans()[1]) then return end
    GC.ControlRequest = request.id
    if request.command == "start" then
        GetConVar("garrycraft_bridge"):SetString(request.bridge)
        GC.Start(player.GetHumans()[1])
    elseif request.command == "stop" then GC.Stop()

    elseif request.command == "test" then
        GetConVar("garrycraft_bridge"):SetString(request.bridge)
        GC.RunLabTest(player.GetHumans()[1])
    elseif request.command == "kill" then player.GetHumans()[1]:Kill()
    elseif request.command == "damage" then
        local owner = player.GetHumans()[1]
        local hit = DamageInfo()
        hit:SetDamage(request.amount)
        hit:SetDamageType(DMG_GENERIC)
        local attacker
        if request.attacker then
            attacker = ents.Create(request.attacker)
            attacker:SetPos(owner:GetPos() + Vector(64, 0, 0))
            attacker:Spawn()
            hit:SetAttacker(attacker)
        end
        owner:TakeDamageInfo(hit)
        if attacker then attacker:Remove() end
    elseif request.command == "look" then player.GetHumans()[1]:SetEyeAngles(Angle(request.pitch, request.yaw, 0))
    elseif request.command == "terrain-check" then GC.CheckDisplacements()
    elseif request.command == "observe" then
        local owner = player.GetHumans()[1]
        local target, sequence = GC.RespawnTarget()
        file.Write("garrycraft-observation.json", util.TableToJSON({position = GC.ToMinecraft(owner:GetPos()),
            spawn = GC.ToMinecraft(target), teleportSeq = sequence, alive = owner:Alive(),
            health = owner:Health(), waterLevel = owner:WaterLevel(), contents = util.PointContents(owner:GetPos()), water = GC.WaterGrid(owner)}))
    elseif request.command == "water-survey" then
        local points = {}
        for x = -4096, 4096, 256 do
            for y = -4096, 4096, 256 do
                for z = -512, 0, 128 do
                    if bit.band(util.PointContents(Vector(x, y, z)), CONTENTS_WATER) ~= 0 then
                        points[#points + 1] = {x, y, z}
                    end
                end
            end
        end
        file.Write("garrycraft-water-survey.json", util.TableToJSON(points))
    elseif request.command == "water-check" then
        local points = {}
        local wet, missing = 0, 0
        -- Query Source directly. Neither player's position changes.
        for x = -3200, 2048, 32 do
            for y = 1792, 4352, 32 do
                if bit.band(util.PointContents(Vector(x, y, -256)), CONTENTS_WATER) ~= 0 then
                    wet = wet + 1
                    local height = GC.WaterSurface(x, y)
                    if height <= -8 then missing = missing + 1 points[#points + 1] = {x, y, height} end
                end
            end
        end
        file.Write("garrycraft-water-check.json", util.TableToJSON({wet = wet, missing = missing, points = points}))
    end
end)
