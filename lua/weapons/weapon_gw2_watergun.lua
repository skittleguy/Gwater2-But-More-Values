SWEP.PrintName = "Water Gun"
    
SWEP.Author = "Mee / Neatro / googer_" 
SWEP.Purpose = "shoots water"
SWEP.Instructions = "you'll figure it out"
SWEP.Category = "GWater2" 
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Weight = 1

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Delay = 0

SWEP.Base = "weapon_base"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo		= "none"
SWEP.Secondary.Delay = 0

SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 70
SWEP.ViewModel			= "models/gwater2/water_gun.mdl" 
SWEP.WorldModel			= "models/weapons/w_pistol.mdl"
SWEP.UseHands           = true

function SWEP:Initialize()

end 

function SWEP:PrimaryAttack()
	if CLIENT then return end
	
	self:SetNextPrimaryFire(CurTime() + 1/10) -- gwater runs at fixed 60 fps

	local owner = self:GetOwner()
	local forward = owner:EyeAngles():Forward() * (gwater2.parameters.radius or 10) * 2
	
	local start_pos = owner:EyePos() + owner:EyeAngles():Right() * 10 - owner:EyeAngles():Up() * 10
	local pos = util.QuickTrace(start_pos, owner:GetAimVector() * 50, owner).HitPos

	gwater2.AddCube(gwater2.quick_matrix(pos, Angle()), Vector(5, 5, 5),{vel = forward})
	owner:EmitSound("Water.ImpactSoft")
end

function SWEP:Reload()
	if CLIENT then return end

	--local owner = self:GetOwner()
	--local forward = owner:EyeAngles():Forward()
	--gwater2.AddSphere(gwater2.quick_matrix(owner:EyePos() + forward * 250), 20, {vel = forward * 10})

	gwater2.ResetSolver()
end

function SWEP:SecondaryAttack()
	if CLIENT then return end

	local owner = self:GetOwner()
	local forward = owner:EyeAngles():Forward()
	gwater2.AddSphere(gwater2.quick_matrix(owner:EyePos() + forward * 25 * (gwater2.parameters.radius or 10)), 20, {vel = forward * 10})
end

if SERVER then return end

function SWEP:DrawHUD()
	if !gwater2 then
		local a = 255 * (math.sin(CurTime() * 2) + 1) / 2
		draw.DrawText("Failed to load GWater2!", "Trebuchet24", ScrW() / 2, ScrH() / 2 - 36, Color(255, 50, 50, a), TEXT_ALIGN_CENTER)
	else
		draw.DrawText("Left-Click to Spawn Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
		draw.DrawText("Right-Click to Open Gun Menu", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
		draw.DrawText("Reload to Remove All", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.81, color_white, TEXT_ALIGN_RIGHT)
	end
end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
function SWEP:PostDrawViewModel(vm, weapon, ply)
	if !gwater2 then return end

	local owner = self:GetOwner() -- me!
	local bone = owner:GetViewModel():LookupBone("ValveBiped.Bip01_R_Hand")
	local pos, ang = owner:GetHands():GetBonePosition(bone)
	pos = pos + ang:Forward() * 5 + ang:Up() * -11 + ang:Right() * 0
	local _, ang = LocalToWorld(vector_origin, Angle(0, -90, 90), vector_origin, EyeAngles())

	cam.Start3D2D(pos, ang, 0.03)
		local text = "Water Particles: " .. format_int(gwater2.solver:GetActiveParticles()) .. "/" .. format_int(gwater2.solver:GetMaxParticles())
		local text2 = "Foam Particles: " .. format_int(gwater2.solver:GetActiveDiffuseParticles()) .. "/" .. format_int(gwater2.solver:GetMaxDiffuseParticles())
		draw.DrawText(text, "CloseCaption_Normal", 4, -24, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(text, "CloseCaption_Normal", 2, -26, color_white, TEXT_ALIGN_CENTER)

		draw.DrawText(text2, "CloseCaption_Normal", 2, 2, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(text2, "CloseCaption_Normal", 0, 0, color_white, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end