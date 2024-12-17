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
SWEP.ViewModel			= "models/weapons/c_pistol.mdl" 
SWEP.WorldModel			= "models/weapons/w_pistol.mdl"
SWEP.UseHands           = true

if CLIENT then
	SWEP.ParticleVelocity = CreateClientConVar("gwater2_gun_velocity",  10, true, true, "",   0,  100)
	SWEP.ParticleDistance = CreateClientConVar("gwater2_gun_distance", 250, true, true, "", 100, 1000)
	SWEP.ParticleDensity  = CreateClientConVar("gwater2_gun_density",    1, true, true, "", 0.1,   10)
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
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!

	local owner = self:GetOwner()
	local forward = owner:EyeAngles():Forward()
	
	local pos = util.QuickTrace(owner:EyePos(),
								owner:GetAimVector() * owner:GetInfoNum("gwater2_gun_distance", 250),
								owner).HitPos + owner:GetAimVector() * -10
	pos = owner:EyePos() + (
		(pos - owner:EyePos()) *
		(gwater2.parameters.fluid_rest_distance or 0.55) *
		owner:GetInfoNum("gwater2_gun_density", 1)
	)

	gwater2.AddCylinder(
		gwater2.quick_matrix(
			pos,
			owner:EyeAngles() + Angle(90, 0, 0),
			1),
		Vector(4, 4, 1),
		{vel = forward * owner:GetInfoNum("gwater2_gun_velocity", 10)}
	)
end

function SWEP:SecondaryAttack()
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!

	--local owner = self:GetOwner()
	--local forward = owner:EyeAngles():Forward()
	--gwater2.AddSphere(gwater2.quick_matrix(owner:EyePos() + forward * 250), 20, {vel = forward * 10})

	gwater2.ResetSolver()
end

function SWEP:Reload()
	if SERVER then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!
end

if SERVER then return end

function SWEP:DrawHUD()
	--surface.DrawCircle(ScrW() / 2, ScrH() / 2, gwater2["size"] * gwater2["density"] * 4 * 10, 255, 255, 255, 255)
	draw.DrawText("Left-Click to Spawn Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Right-Click to Remove All", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Reload to Open Menu", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.81, color_white, TEXT_ALIGN_RIGHT)
end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
local csent = ClientsideModel("models/hunter/tubes/tube2x2x1.mdl")
csent:SetMaterial("models/wireframe")
csent:SetNoDraw(true)
function SWEP:PostDrawViewModel(vm, weapon, ply)
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
								ply).HitPos - ply:GetAimVector() * 10
	angles:RotateAroundAxis(angles:Right(), 90)
	cam.Start3D2D(pos, angles, 0.03)
		surface.DrawCircle(0, 0, 160 * 5 * self.ParticleDensity:GetFloat(), 255, 255, 255, 255)
		for i=0,5,1 do
			surface.DrawCircle(0, 0, 160 * 5 * self.ParticleDensity:GetFloat() *
									 ((100-self.ParticleVelocity:GetFloat()*(math.log(i)+2)/2.6)/200), 255, 255, 255, 255)
		end
	cam.End3D2D()
end

--[[ -- Benchmarking stuff (ignore)
local avg = 0
local line = 0
local lines = {}
surface.SetDrawColor(0, 255, 0, 255)
avg = avg + (RealFrameTime() - avg) * 0.01

lines[line] = -(6 / avg) + 1080
for i = 0, 1920 do

	if !lines[i - 1] or !lines[i] then continue end
	surface.DrawLine(i * 1, lines[i - 1], i * 1 + 1, lines[i])
end


line = (line + 1) % 1920]]
