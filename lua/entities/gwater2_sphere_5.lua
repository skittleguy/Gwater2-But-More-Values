AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category = "GWater2"
ENT.PrintName = "Sphere (5)"
ENT.Author = "Meetric"
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = true

ENT.GWater2_LESPAWN_RADIUS = 5

function ENT:SpawnFunction(ply, tr, class, type)
	local radius = gwater2.parameters.radius or 10
	gwater2.AddSphere(
		gwater2.quick_matrix(tr.HitPos + tr.HitNormal * (self.GWater2_LESPAWN_RADIUS*radius)),
		self.GWater2_LESPAWN_RADIUS,
		{}
	)
end
-- dont.
function ENT:Draw()
	self:SetNoDraw(true)
end