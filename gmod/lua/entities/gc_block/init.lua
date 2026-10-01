AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:SetNoDraw(true)
    self:PhysicsInitMultiConvex(self.Convexes)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:EnableCustomCollisions(true)
    self:GetPhysicsObject():EnableMotion(false)
end
