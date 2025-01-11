AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"
ENT.AdminOnly = false
ENT.PrintName = "Clean Up"
ENT.Category = "GWater2"
ENT.Author = "AndrewEathan"
ENT.Spawnable = true

function ENT:SpawnFunction(ply, tr, ClassName)
	gwater2.ResetSolver()

	return nil
end