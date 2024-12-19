SWEP.PrintName = "Pickup Gun"
    
SWEP.Author = "googer_" 
SWEP.Purpose = "picks up water"
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
SWEP.ViewModel			= "models/weapons/c_stunstick.mdl" 
SWEP.WorldModel			= "models/weapons/w_stunbaton.mdl"
SWEP.UseHands           = true

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

hook.Add("gwater2_tick_drains", "gwater2_gravgun_grab", function()
	for _,ply in pairs(player.GetAll()) do
		local weapon = ply:GetActiveWeapon()
		if not IsValid(weapon) or weapon:GetClass() ~= "weapon_gw2_gravgun" then continue end
		if CurTime() - ply:GetNWFloat("GWATER2_HOLDSWATER", -100) < 0.5 then
			local delta = (CurTime() - ply:GetNWFloat("GWATER2_HOLDSWATER", -100)) / 0.5
			gwater2.solver:AddForceField(ply:EyePos() + ply:GetAimVector() * 170, 150, -150 * (1-delta), 0, true)
		end
		if CurTime() - ply:GetNWFloat("GWATER2_PUNTWATER", -100) < 0.066*5 then
			local delta = (CurTime() - ply:GetNWFloat("GWATER2_PUNTWATER", -100)) / (0.066*5)
			gwater2.solver:AddForceField(ply:EyePos() + ply:GetAimVector() * 70, 150, 100 * delta, 1, false)
		end
	end
end)

local last = 1
function SWEP:PrimaryAttack()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!
	self:SetNextPrimaryFire(CurTime() + 1/60) -- gwater runs at fixed 60 fps

	local owner = self:GetOwner()

	owner:SetNWFloat("GWATER2_HOLDSWATER", CurTime())
	last = (last == 1 and 2 or 1)
	owner:GetViewModel():ResetSequence("misscenter"..last)
end

function SWEP:SecondaryAttack()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!
	self:SetNextPrimaryFire(CurTime() + 1/60) -- gwater runs at fixed 60 fps

	local owner = self:GetOwner()

	owner:SetNWFloat("GWATER2_PUNTWATER", CurTime())
	owner:GetViewModel():ResetSequence("hitcenter"..math.floor(CurTime()*5%3+1))
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
	draw.DrawText("Left-Click to Pickup Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText("Right-Click to Punt Particles", "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
end