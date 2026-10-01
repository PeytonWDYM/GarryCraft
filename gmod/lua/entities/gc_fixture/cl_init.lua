include("shared.lua")
local material = Material("models/debug/debugwhite")
local color = Color(80, 140, 200)

function ENT:Draw()
    render.SetMaterial(material)
    local minimum, maximum = self:GetNWVector("Minimum"), self:GetNWVector("Maximum")
    if not self:GetNWBool("Ramp") then
        render.DrawBox(self:GetPos(), self:GetAngles(), minimum, maximum, color)
        return
    end
    local a = self:LocalToWorld(Vector(minimum.x, maximum.y, 0))
    local b = self:LocalToWorld(Vector(maximum.x, maximum.y, 0))
    local c = self:LocalToWorld(Vector(maximum.x, minimum.y, maximum.z))
    local d = self:LocalToWorld(Vector(minimum.x, minimum.y, maximum.z))
    local e = self:LocalToWorld(Vector(maximum.x, minimum.y, 0))
    local f = self:LocalToWorld(Vector(minimum.x, minimum.y, 0))
    render.DrawQuad(a, b, c, d, color)
    render.DrawQuad(d, c, b, a, color)
    render.DrawQuad(b, e, c, c, color)
    render.DrawQuad(a, d, f, f, color)
    render.DrawQuad(d, c, e, f, color)
end
