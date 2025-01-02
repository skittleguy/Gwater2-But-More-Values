AddCSLuaFile()

-- "Refusing to load gwater2_cube because it is missing Type and Base keys!"
ENT.Type = "point"
ENT.Base = "base_point"
--

local xyz = {
	Vector(50, 50),
	Vector(100, 100),
	Vector(200, 200)
}

for k, v in ipairs(xyz) do
	local ENT = scripted_ents.Get("base_point")	
	ENT.Type = "point"
	ENT.Base = "base_point"
	ENT.AdminOnly = false
	ENT.PrintName = "Cloth (" .. v.x .. ")"
	ENT.Category = "GWater2"
	ENT.Author = "AndrewEathan"
	ENT.Spawnable = true
	
	function ENT:SpawnFunction(ply, tr, ClassName)
		gwater2.AddCloth(gwater2.quick_matrix(tr.HitPos + Vector(0, 0, 50)), v)

		gwater2.cloth_exists = true

		undo.Create("Cloth (all)")
			undo.AddFunction(function(undo, vararg)
				if not gwater2.cloth_exists then return false end
				gwater2.cloth_exists = false
				gwater2.RemoveCloth()
				return true
			end)
			undo.SetPlayer(ply)
		undo.Finish()
		return nil
	end

	scripted_ents.Register(ENT, "gwater2_cloth_" .. v.x)
end