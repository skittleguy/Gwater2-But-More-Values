AddCSLuaFile()

-- "Refusing to load gwater2_cube because it is missing Type and Base keys!"
ENT.Type = "point"
ENT.Base = "base_point"
--

local xyz = {
	Vector(5, 5, 5),
	Vector(10, 10, 10),
	Vector(20, 20, 20),
}

for k, v in ipairs(xyz) do
	local ENT = scripted_ents.Get("base_point")	
	ENT.Type = "point"
	ENT.Base = "base_point"
	ENT.AdminOnly = false
	ENT.PrintName = "Cube (" .. v.x .. ")"
	ENT.Category = "GWater2"
	ENT.Author = "AndrewEathan"
	ENT.Spawnable = true
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		gwater2.AddCube(gwater2.quick_matrix(tr.HitPos + tr.HitNormal * v.x * (gwater2.parameters.radius or 10) / 2), v)

		return nil
	end

	scripted_ents.Register(ENT, "gwater2_cube_" .. v.x)
end