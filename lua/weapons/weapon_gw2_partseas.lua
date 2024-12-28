SWEP.PrintName = "Part The Seas"
    
SWEP.Author = "Meetric" 
SWEP.Purpose = "roleplay as moses"
SWEP.Instructions = "Left click to part the seas"
SWEP.Category = "GWater2" 
SWEP.DrawAmmo       = true
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = true

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Weight = 1

SWEP.Primary.Ammo          = "none"	-- needs to be something to show ammo

SWEP.Base = "weapon_base"
SWEP.Secondary.Ammo          = "none"

SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 70
SWEP.ViewModel			= "models/weapons/c_arms.mdl" 
SWEP.WorldModel			= ""
SWEP.UseHands           = true

if CLIENT then return end

function SWEP:create_black_holes(strength)
	if self.BLACK_HOLES then return end

	self.BLACK_HOLES = {}

	local start_pos = self:GetOwner():EyePos()
	local end_pos = self:GetOwner():GetEyeTrace().HitPos
	timer.Create(self, 0.1, start_pos:Distance(end_pos) / 100, function()
		local black_hole = ents.Create("gwater2_blackhole")
		black_hole:SetPos(start_pos)
		black_hole:SetNotSolid(true)
		table.insert(black_hole)
	end)
end

function SWEP:destroy_black_holes()
	if !self.BLACK_HOLES then return end
	
	for k, v in ipairs(self.BLACK_HOLES) do
		SafeRemoveEntity(v)
	end
	
	self.BLACK_HOLES = nil
end

function SWEP:PrimaryAttack()
	self:make_black_holes(-100)
	print("Hello World!")
end

function SWEP:Reload()

end

function SWEP:SecondaryAttack()

	print("Hello World")
end

function SWEP:OnDrop()
	self:Remove() -- "You can't drop fists"
end

if SERVER then return end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
function SWEP:PostDrawViewModel(vm, weapon, ply)
	if !gwater2 then 
		cam.Start2D()
			local a = 255 * (math.sin(CurTime() * 2) + 1) / 2
			draw.DrawText("Failed to load GWater2!", "Trebuchet24", ScrW() / 2, ScrH() / 2 - 36, Color(255, 50, 50, a), TEXT_ALIGN_CENTER)
		cam.End2D()

		return 
	end

	local owner = self:GetOwner() -- me!
	local bone = owner:GetViewModel():LookupBone("ValveBiped.Bip01_R_Hand")
	local pos, ang = owner:GetHands():GetBonePosition(bone)
	pos = pos + ang:Forward() * 5 + ang:Up() * -11 + ang:Right() * 0
	local _, ang = LocalToWorld(vector_origin, Angle(0, -90, 90), vector_origin, EyeAngles())

	self.Weapon:SetClip1(gwater2.solver:GetMaxParticles() - gwater2.solver:GetActiveParticles())
end