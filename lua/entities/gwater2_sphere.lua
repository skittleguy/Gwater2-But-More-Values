AddCSLuaFile()

-- "Refusing to load gwater2_cube because it is missing Type and Base keys!"
ENT.Type = "point"
ENT.Base = "base_point"
--

local xyz = {
	5,
	10,
	20
}

for k, v in ipairs(xyz) do
	local ENT = scripted_ents.Get("base_point")	
	ENT.Type = "point"
	ENT.Base = "base_point"
	ENT.AdminOnly = false
	ENT.PrintName = "Sphere (" .. v .. ")"
	ENT.Category = "GWater2"
	ENT.Author = "AndrewEathan"
	ENT.Spawnable = true
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		gwater2.AddSphere(gwater2.quick_matrix(tr.HitPos + tr.HitNormal * v * (gwater2.parameters.radius or 10)), v)

		return nil
	end

	scripted_ents.Register(ENT, "gwater2_sphere_" .. v)
end