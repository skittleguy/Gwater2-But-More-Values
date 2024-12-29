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
SWEP.Primary.Automatic     = false

SWEP.Base = "weapon_base"
SWEP.Secondary.Ammo          = "none"
SWEP.Secondary.Automatic     = false

SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 70
SWEP.ViewModel			= "models/weapons/c_arms.mdl" 
SWEP.WorldModel			= ""
SWEP.UseHands           = true

function SWEP:Initialize()
	self:SetHoldType("magic")
end

if CLIENT then return end

function SWEP:create_black_holes(strength)
	if self.BLACK_HOLES then 
		self:destroy_black_holes()
	end

	local owner = self:GetOwner()
	local start_pos = owner:GetPos() + owner:OBBCenter() / 2
	local end_pos = util.QuickTrace(start_pos, (owner:GetAimVector() * Vector(1, 1, 0)):GetNormalized() * 10000, owner).HitPos
	local max_points = math.floor(start_pos:Distance(end_pos) / 200)

	self.BLACK_HOLES = {}
	local points = 0
	timer.Create("gwater2_partseas_create" .. self:EntIndex(), 0.1, max_points, function()
		for i = 0, 1 do
			local black_hole = ents.Create("gwater2_blackhole")
			black_hole:SetPos(LerpVector(points / max_points, start_pos, end_pos) + Vector(0, 0, i * 400))
			black_hole:SetRadius(300)
			black_hole:SetStrength(strength)
			black_hole:SetMode(1)
			black_hole:SetLinear(1)
			black_hole:Spawn()
			black_hole:SetNotSolid(true)
			black_hole:SetRenderMode(RENDERMODE_NONE)
			black_hole:GetPhysicsObject():EnableMotion(false)
			table.insert(self.BLACK_HOLES, black_hole)
		end
		points = points + 1
	end)

	timer.Create("gwater2_partseas_destroy" .. self:EntIndex(), 30, 1, function()
		self:destroy_black_holes()
	end)
end

function SWEP:destroy_black_holes()
	if !self.BLACK_HOLES then return end
	
	timer.Remove("gwater2_partseas_create" .. self:EntIndex())
	timer.Remove("gwater2_partseas_destroy" .. self:EntIndex())

	for k, v in ipairs(self.BLACK_HOLES) do
		SafeRemoveEntity(v)
	end
	
	self.BLACK_HOLES = nil
end

function SWEP:PrimaryAttack()
	self:create_black_holes(-100)
end

function SWEP:Reload()
	self:destroy_black_holes()
end

function SWEP:SecondaryAttack()
	self:create_black_holes(100)
end

function SWEP:OnDrop()
	self:destroy_black_holes()
	self:Remove() -- "You can't drop fists"
end

function SWEP:OnRemove()
	self:destroy_black_holes()
end