local GC = GarryCraft
local floor
local obstacle
local currentCase
local waterWall
local polishRequest

local function surface(minimum, maximum, ramp)
    local entity = ents.Create("gc_fixture")
    entity:SetPos(GC.LabOrigin + GC.DirectionToSource(-0.5, 0, -0.5))
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
    if name == "fast-low-wall" or name == "elytra-low-wall" then obstacle = surface(Vector(-96, -288, 0), Vector(160, -256, 32)) end
    if name == "fast-wall" or name == "elytra-wall" then obstacle = surface(Vector(-96, -288, 0), Vector(160, -256, 160)) end
end

function GC.RunLabTest(caller)
    assert(game.SinglePlayer(), "GarryCraft tests require a local single-player map")
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    if IsValid(floor) then floor:Remove() end
    GC.LabOrigin = Vector(16, -16, 8192)
    owner:SetPos(GC.LabOrigin)
    floor = surface(Vector(-256, -1568, -32), Vector(1312, 256, 0))
    floor:SetNWBool("GarryCraftStatic", true)
    owner:SetEyeAngles(Angle(0, -90, 0))
    GC.BeginTest(owner, tostring(SysTime()))
end
concommand.Add("garrycraft_test", function(caller, _, arguments)
    if arguments[1] == "polish" then
        if IsValid(waterWall) then waterWall:Remove() end
        local position = GC.ToMinecraft(caller:GetPos())
        waterWall = ents.Create("gc_fixture")
        waterWall:SetPos(GC.ToSource(math.floor(position[1])-2, math.floor(position[2]), math.floor(position[3])+1))
        waterWall:SetNWVector("Minimum", Vector(0,-160,-32))
        waterWall:SetNWVector("Maximum", Vector(2,0,64))
        waterWall:Spawn()
        polishRequest = "polish:" .. tostring(SysTime())
        GC.BeginTest(caller, polishRequest)
    elseif arguments[1] == "reload" then GC.BeginTest(caller, "reload:" .. tostring(SysTime()))
    elseif arguments[1] == "responsiveness" then GC.BeginTest(caller, "responsiveness:" .. tostring(SysTime()))
    elseif arguments[1] == "damage" then GC.RunDamageTest(caller)
    elseif arguments[1] == "terrain" then GC.RunTerrainTest(caller)
    elseif arguments[1] == "entities" then GC.RunEntityTest(caller) else GC.RunLabTest(caller) end
end)

function GC.PolishSample(state)
    if state.polishRequest == polishRequest and state.polishPhase == "done" and IsValid(waterWall) then waterWall:Remove() end
end

hook.Add("Think", "GarryCraftPolishCleanup", function()
    if IsValid(waterWall) and not GC.IsActive() then waterWall:Remove() end
end)

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
    -- Consume each command before execution so map entry cannot replay it, even after an error.
    file.Delete("garrycraft-control.json")
    if request.command == "start" then
        GetConVar("garrycraft_bridge"):SetString(request.bridge)
        GC.Start(player.GetHumans()[1])
    elseif request.command == "stop" then GC.Stop()

    elseif request.command == "test" then
        GetConVar("garrycraft_bridge"):SetString(request.bridge)
        if request.scenario == "responsiveness" then GC.BeginTest(player.GetHumans()[1], "responsiveness:" .. tostring(SysTime()))
        elseif request.scenario == "damage" then GC.RunDamageTest(player.GetHumans()[1])
        elseif request.scenario == "terrain" then GC.RunTerrainTest(player.GetHumans()[1])
        elseif request.scenario == "entities" then GC.RunEntityTest(player.GetHumans()[1]) else GC.RunLabTest(player.GetHumans()[1]) end
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
    elseif request.command == "report" then
        player.GetHumans()[1]:ConCommand("garrycraft_render_report\ngarrycraft_world_report\ngarrycraft_blocks_report\ngarrycraft_frame_report\n")
    elseif request.command == "observe" then
        local owner = player.GetHumans()[1]
        local target, sequence = GC.RespawnTarget()
        file.Write("garrycraft-observation.json", util.TableToJSON({position = GC.ToMinecraft(owner:GetPos()),
            spawn = GC.ToMinecraft(target), teleportSeq = sequence, alive = owner:Alive(),
            god = owner:HasGodMode(),
            mobTargets = #ents.FindByClass("npc_bullseye"), blockEntities = #ents.FindByClass("gc_block"),
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
