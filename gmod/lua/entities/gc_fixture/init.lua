AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    local minimum = self:GetNWVector("Minimum")
    local maximum = self:GetNWVector("Maximum")
    if self:GetNWBool("Ramp") then
        self:PhysicsInitConvex({
            Vector(minimum.x, maximum.y, 0), Vector(maximum.x, maximum.y, 0),
            Vector(minimum.x, minimum.y, 0), Vector(maximum.x, minimum.y, 0),
            Vector(minimum.x, minimum.y, maximum.z), Vector(maximum.x, minimum.y, maximum.z)
        })
    else self:PhysicsInitBox(minimum, maximum) end
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionBounds(minimum, maximum)
    self:GetPhysicsObject():EnableMotion(false)
end
