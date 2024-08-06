AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Cloth (50x50)"
ENT.Author			= "Meetric"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable 		= true

-- send cloth data to the client
function ENT:SpawnFunction(ply, tr, class, type)
	local pos = tr.HitPos + Vector(0, 0, 50)
	gwater2.AddCloth(pos, Vector(200, 200))	-- network

	local ent = ents.Create(class)
	ent:SetPos(pos)
	ent:Spawn()

	return ent
end

-- dont.
function ENT:Draw()

end

-- remove all cloth, as theres not a way to remove individually yet
function ENT:OnRemove()
	if CLIENT then
		gwater2.solver:Reset()
	else
		for k, v in ipairs(ents.FindByClass("gwater2_cloth_*")) do	-- die
			SafeRemoveEntity(v)
		end
	end
end
