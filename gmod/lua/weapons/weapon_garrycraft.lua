AddCSLuaFile()
SWEP.Base = "weapon_base"
SWEP.PrintName = "Minecraft"
SWEP.Spawnable = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
-- Native animation queries still need a studio header even while Minecraft hides this weapon.
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:DrawWorldModel() end
