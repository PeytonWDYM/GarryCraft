ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minecraft physics block"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "BlockId")
    self:NetworkVar("String", 0, "BlockSession")
end
