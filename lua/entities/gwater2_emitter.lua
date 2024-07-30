AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Emitter"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable    = true

function ENT:Initialize()
	if CLIENT then 
		hook.Add("gwater2_pretick", self, function()
			local mat = Matrix()
			mat:SetScale(Vector(6.5, 6.5, 6.5))
			mat:SetAngles(self:LocalToWorldAngles(Angle(0, CurTime() * 200, 0)))
			mat:SetTranslation(self:GetPos() + self:GetUp() * 10)
		
			gwater2.solver:AddCube(mat, Vector(10, 1, 1), {vel = self:GetUp() * 60})
		end)
	else
		self:SetModel("models/mechanics/wheels/wheel_speed_72.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
	end
end

function ENT:OnRemove()
	hook.Remove("gwater2_pretick", self)
end