local GC = GarryCraft
local sections = {}
local acknowledged = 0
local clientAck = 0
local owner
local session
local instance
util.AddNetworkString("garrycraft_world_ack")

local function clear()
    for _, entity in pairs(sections) do if IsValid(entity) then entity:Remove() end end
    sections = {}
end

function GC.BlocksBegin(player, nextSession)
    clear()
    owner, session, instance = player, nextSession, nil
    acknowledged, clientAck = 0, 0
end
function GC.BlocksStop() clear() owner = nil end
function GC.BlocksAck() return math.min(acknowledged, clientAck) end
function GC.BlocksInstance() return instance or "" end

net.Receive("garrycraft_world_ack", function(_, player)
    local ack = net.ReadUInt(32)
    local process = net.ReadString()
    if player == owner and process == instance then clientAck = math.max(clientAck, ack) end
end)

-- Vanilla collision shapes become Source convexes. Source NPCs and props use these shapes directly.
function GC.BlocksPoll(process)
    local payload = garrycraft_bridge.receive(7)
    if not payload then return end
    local boundary = assert(string.find(payload, "\n", 1, true), "Missing world packet header")
    local section = util.JSONToTable(string.sub(payload, 1, boundary - 1))
    if section.session ~= session or section.instance ~= process then return end
    if instance ~= process then clear() instance = process acknowledged, clientAck = 0, 0 end
    if section.sequence <= acknowledged then return end
    if section.clear then clear() else
        local previous = sections[section.key]
        if IsValid(previous) then previous:Remove() end
        sections[section.key] = nil
        if #section.boxes > 0 then
            local convexes = {}
            local origin = GC.ToSource(section.boxes[1][1], section.boxes[1][2], section.boxes[1][3])
            for _, box in ipairs(section.boxes) do
                local corners = {}
                for _, x in ipairs({box[1], box[4]}) do
                    for _, y in ipairs({box[2], box[5]}) do
                        for _, z in ipairs({box[3], box[6]}) do
                            corners[#corners + 1] = GC.ToSource(x, y, z) - origin
                        end
                    end
                end
                convexes[#convexes + 1] = corners
            end
            local entity = ents.Create("gc_block")
            entity:SetPos(origin)
            entity.Convexes = convexes
            entity:Spawn()
            sections[section.key] = entity
        end
    end
    acknowledged = section.sequence
end

hook.Add("ShutDown", "GarryCraftBlockCleanup", clear)
