include("shared.lua")

function ENT:Initialize()
    self:DrawShadow(false)
end

function ENT:GetRenderMesh()
    local batch = self.GarryCraftPhysicsBatch
    if not batch then return end
    return {Mesh = batch.mesh, Material = GarryCraft.RenderMaterial(batch)}
end

function ENT:Draw(flags)
    GarryCraft.DrawPhysicsBlock(self, flags, false)
end

function ENT:DrawTranslucent(flags)
    GarryCraft.DrawPhysicsBlock(self, flags, true)
end

function ENT:OnRemove()
    garrycraft_bridge.shadow_remove(self)
end
