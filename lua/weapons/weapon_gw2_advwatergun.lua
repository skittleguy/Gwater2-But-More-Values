-- dont remove mee

SWEP.PrintName = "Advanced Water Gun"
    
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
SWEP.ViewModel			= "models/weapons/c_pistol.mdl" 
SWEP.WorldModel			= "models/weapons/w_pistol.mdl"
SWEP.UseHands           = true

if CLIENT then
	SWEP.ParticleVelocity = CreateClientConVar("gwater2_gun_velocity",  10, true, true, "",   0,  100)
	SWEP.ParticleDistance = CreateClientConVar("gwater2_gun_distance", 250, true, true, "", 100, 1000)
	SWEP.ParticleSpread  = CreateClientConVar("gwater2_gun_spread",    1, true, true, "", 0.1,   10)

	-- 1 is cylinder (default) (introduced in 0.5b iirc)
	-- 2 is box (introduced in 0.1b)
	SWEP.SpawnMode  = CreateClientConVar("gwater2_gun_spawnmode", 1, true, true, "", 1, 2)
end

local function fuckgarry(w, s)
	if SERVER then 
		if game.SinglePlayer() then 
			w:CallOnClient(s) 
		end
		return true
	end
	return IsFirstTimePredicted()
end

function SWEP:Initialize()

end 

function SWEP:PrimaryAttack()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!
	self:SetNextPrimaryFire(CurTime() + 1/60) -- gwater runs at fixed 60 fps

	local owner = self:GetOwner()
	local forward = owner:GetAimVector()
	
	local pos = util.QuickTrace(owner:EyePos(),
								forward * owner:GetInfoNum("gwater2_gun_distance", 250),
								owner).HitPos

	local mode = math.floor(owner:GetInfoNum("gwater2_gun_spawnmode", 1))

	pos = pos + forward * -(gwater2.parameters.radius or 10)
	pos = owner:EyePos() + (
		(pos - owner:EyePos()) *
		(gwater2.parameters.fluid_rest_distance or 0.55)
	)
    local eyeangles = owner:EyeAngles()
    local owneraddvel = owner:GetVelocity():Dot(forward) * forward / 25.4
	if mode == 1 then
		gwater2.AddCylinder(
			gwater2.quick_matrix(
				pos,
				eyeangles + Angle(90, 0, 0),
				owner:GetInfoNum("gwater2_gun_spread", 1)),
			Vector(4 * owner:GetInfoNum("gwater2_gun_spread", 1), 4 * owner:GetInfoNum("gwater2_gun_spread", 1), 1),
			{vel = forward * owner:GetInfoNum("gwater2_gun_velocity", 10) + owneraddvel}
		)
	end
	if mode == 2 then
		local size = 4 * owner:GetInfoNum("gwater2_gun_spread", 1)
		pos = pos + owner:GetAimVector() * (gwater2.parameters.radius or 10) * (size+1)
		pos = pos + owner:GetAimVector() * -(gwater2.parameters.radius or 10) * 5
		gwater2.AddCube(
			gwater2.quick_matrix(
				pos,
				eyeangles + Angle(90, 0, 0),
				owner:GetInfoNum("gwater2_gun_spread", 1)),
				Vector(size, size, size),
				{vel = forward * owner:GetInfoNum("gwater2_gun_velocity", 10) + owneraddvel}
		)
	end
    if CurTime() - (self.GWATER2_LastEmitSound or 0) > 0.1 then
        self:EmitSound("Water.ImpactSoft")
        self.GWATER2_LastEmitSound = CurTime()
    end
end

function SWEP:Reload()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!

	--local owner = self:GetOwner()
	--local forward = owner:EyeAngles():Forward()
	--gwater2.AddSphere(gwater2.quick_matrix(owner:EyePos() + forward * 250), 20, {vel = forward * 10})

	gwater2.ResetSolver()
end

local frame
function SWEP:SecondaryAttack()
	if not gwater2 then return end
	if SERVER then
		if not IsFirstTimePredicted() then return end
		return game.SinglePlayer() and self:CallOnClient("SecondaryAttack")
	end

	if IsValid(frame) then return frame:Close() end
	frame = include("menu/gwater2_gunmenu.lua")(self)
end

if SERVER then return end

function SWEP:DrawHUD()
	if not gwater2 then
		local a = 255*(math.sin(CurTime()*2)+1)/2
		draw.DrawText("GWater 2 failed to load!", "Trebuchet24", ScrW() / 2 + 1, ScrH() / 2 - 36 + 1, Color(0, 0, 0, a), TEXT_ALIGN_CENTER)
		draw.DrawText("GWater 2 failed to load!", "Trebuchet24", ScrW() / 2, ScrH() / 2 - 36, Color(255, 0, 0, a), TEXT_ALIGN_CENTER)
		return
	end
	--surface.DrawCircle(ScrW() / 2, ScrH() / 2, gwater2["size"] * gwater2["density"] * 4 * 10, 255, 255, 255, 255)
	draw.DrawText("Left-Click to Spawn Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Right-Click to Open Gun Menu", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Reload to Remove All", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.81, color_white, TEXT_ALIGN_RIGHT)
end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
function SWEP:PostDrawViewModel(vm, weapon, ply)
	if not gwater2 then return end
	local pos, ang = vm:GetBonePosition(39)--self:GetOwner():GetViewModel():GetBonePosition(0)
	if !pos or !ang then return end
	ang = ang + Angle(180, 0, -ang[3] * 2)
	pos = pos - ang:Right() * 1.5

	
	cam.Start3D2D(pos, ang, 0.03)
		local text = "Water Particles: " .. format_int(gwater2.solver:GetActiveParticles()) .. "/" .. format_int(gwater2.solver:GetMaxParticles())
		local text2 = "Foam Particles: " .. format_int(gwater2.solver:GetActiveDiffuse()) .. "/" .. format_int(gwater2.solver:GetMaxDiffuseParticles())
		draw.DrawText(text, "CloseCaption_Normal", 4, -24, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(text, "CloseCaption_Normal", 2, -26, color_white, TEXT_ALIGN_CENTER)

		draw.DrawText(text2, "CloseCaption_Normal", 2, 2, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(text2, "CloseCaption_Normal", 0, 0, color_white, TEXT_ALIGN_CENTER)
	cam.End3D2D()

	local angles = ply:EyeAngles()
	local pos = util.QuickTrace(ply:EyePos(),
								ply:GetAimVector() * self.ParticleDistance:GetFloat(),
								ply).HitPos + ply:GetAimVector() * -(gwater2.parameters.radius or 10)
	angles:RotateAroundAxis(angles:Right(), 90)
	if self.SpawnMode:GetInt() == 1 then
		cam.Start3D2D(pos, angles, 0.03)
			--surface.DrawCircle(0, 0, 160 * 5 * self.ParticleSpread:GetFloat(), 255, 255, 255, 255)
			for i=0,5,1 do
				local factor = math.ease.OutCubic(self.ParticleVelocity:GetFloat()/100*(i/5))
				surface.DrawCircle(0, 0, 160 * 5 * self.ParticleSpread:GetFloat() - 160*3*
										factor * self.ParticleSpread:GetFloat(),
										-- (((100-self.ParticleVelocity:GetFloat())*(math.log(i)+1)/2.6)/100),
										255, 255, 255, 255 * (1-factor))
			end
		cam.End3D2D()
	end
	if self.SpawnMode:GetInt() == 2 then
		pos = pos + ply:GetAimVector() * -(gwater2.parameters.radius or 10) * 5
		cam.Start3D2D(pos, angles, 0.03)
		local edge = Vector(4, 4, 4) * self.ParticleSpread:GetFloat()^2 * 2
		for i=0,5,1 do
			local factor = math.ease.OutCubic(self.ParticleVelocity:GetFloat()/100*(i/5))
			surface.SetDrawColor(255, 255, 255, 255 * (1-factor))
			local size = 160 * 3 * self.ParticleSpread:GetFloat() - 160*2*
						 factor * self.ParticleSpread:GetFloat()
			surface.DrawOutlinedRect(-size/2, -size/2, size, size, 2)
		end
		cam.End3D2D()
	end
end
