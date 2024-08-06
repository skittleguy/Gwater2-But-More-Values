AddCSLuaFile()

if SERVER then
	util.AddNetworkString("GWATER2_ADDCLOTH")
	util.AddNetworkString("GWATER2_ADDPARTICLE")
	util.AddNetworkString("GWATER2_ADDCUBE")
	util.AddNetworkString("GWATER2_ADDCYLINDER")
	util.AddNetworkString("GWATER2_ADDSPHERE")

	gwater2 = {
		AddCloth = function(pos, size, particle_data)
			net.Start("GWATER2_ADDCLOTH")
				net.WriteVector(pos)
				net.WriteUInt(size[1], 16)
				net.WriteUInt(size[2], 16)
				net.WriteTable(particle_data or {}) -- empty table only takes 3 bits
			net.Broadcast()
		end,
	}

else	-- CLIENT
	net.Receive("GWATER2_ADDCLOTH", function(len)
		local pos = net.ReadVector()	-- pos
		local size_x = net.ReadUInt(16)
		local size_y = net.ReadUInt(16)
		local extra = net.ReadTable()	-- the one time this function is actually useful
		gwater2.solver:AddCloth(pos, Vector(size_x, size_y), extra)
		gwater2.cloth_pos = pos
	end)

end