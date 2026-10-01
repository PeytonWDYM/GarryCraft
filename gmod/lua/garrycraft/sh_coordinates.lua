GarryCraft.Scale = 32

function GarryCraft.ToMinecraft(position)
    return {position.x / 32, position.z / 32, -position.y / 32}
end

function GarryCraft.ToSource(x, y, z)
    return Vector(x * 32, -z * 32, y * 32)
end
