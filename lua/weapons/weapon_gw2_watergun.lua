SWEP.PrintName = "Water Gun"
    
SWEP.Author = "Mee / Neatro" 
SWEP.Purpose = "shoot water man"
SWEP.Instructions = "just left click"
SWEP.Category = "gwater2" 
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = true --Must be true
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

function SWEP:Initialize()
	self:SetMaterial("hunter/myplastic")
	self:SetModelScale(0.5)
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

function SWEP:PrimaryAttack()
	--self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	if fuckgarry(self, "PrimaryAttack") then return end

	local owner = self:GetOwner()
	local forward = owner:EyeAngles():Forward()
	local sprite_size = gwater2.solver:GetParameter("radius") * math.Rand(1, 1.05)
	local amb = render.GetAmbientLightColor(owner:EyePos())
	gwater2.solver:AddCube(owner:EyePos() + forward * 20 * sprite_size, forward * 100, Vector(4, 4, 4), sprite_size * 0.9, gwater2.color)
end

function SWEP:SecondaryAttack()
	if fuckgarry(self, "SecondaryAttack") then return end

	local owner = self:GetOwner()
	local forward = owner:EyeAngles():Forward()
	local sprite_size = gwater2.solver:GetParameter("fluid_rest_distance")
	gwater2.solver:AddCube(owner:EyePos() + forward * 40 * sprite_size, forward * 100, Vector(33, 33, 33), sprite_size * 0.9, gwater2.color)
end

function SWEP:DrawHUD()
	draw.DrawText("Left-Click to Spawn Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Right-Click to Spawn a Cube", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Reload to Remove All", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.81, color_white, TEXT_ALIGN_RIGHT)
end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

function SWEP:PostDrawViewModel(vm, weapon, ply)
	local pos, ang = vm:GetBonePosition(39)--self:GetOwner():GetViewModel():GetBonePosition(0)
	ang = ang + Angle(180, 0, -ang[3] * 2)
	pos = pos - ang:Right() * 1.5
	cam.Start3D2D(pos, ang, 0.03)
		local num_particles = gwater2.solver:GetCount()
		draw.DrawText("Particles: " .. format_int(num_particles) .. "/100,000", "CloseCaption_Normal", 2, 2, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText("Particles: " .. format_int(num_particles) .. "/100,000", "CloseCaption_Normal", 0, 0, color_white, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

function SWEP:Reload()
	if fuckgarry(self, "Reload") then return end
	
	gwater2.solver:Reset()
end

/* -- Benchmarking stuff (ignore)
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


line = (line + 1) % 1920*/