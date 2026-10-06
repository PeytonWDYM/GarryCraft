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
    if GarryCraft then GarryCraft.DrawPhysicsBlock(self, flags, false) end
end

function ENT:DrawTranslucent(flags)
    if GarryCraft then GarryCraft.DrawPhysicsBlock(self, flags, true) end
end

function ENT:OnRemove()
    if GarryCraft then garrycraft_bridge.shadow_remove(self) end
end
