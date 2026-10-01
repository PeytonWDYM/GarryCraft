GarryCraft.Scale = 32
GarryCraft.GridHeight = 0

function GarryCraft.ToMinecraft(position)
    return {position.x / 32, (position.z - GarryCraft.GridHeight) / 32, -position.y / 32}
end

function GarryCraft.ToSource(x, y, z)
    return Vector(x * 32, -z * 32, y * 32 + GarryCraft.GridHeight)
end

function GarryCraft.DirectionToSource(x, y, z) return Vector(x * 32, -z * 32, y * 32) end

if CLIENT then
    hook.Add("PreRender", "GarryCraftGrid", function()
        if IsValid(LocalPlayer()) then GarryCraft.GridHeight = LocalPlayer():GetNWFloat("GarryCraftGridHeight") end
    end)
end
