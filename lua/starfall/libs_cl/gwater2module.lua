AddCSLuaFile()
local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege

--- Library for using gwater2
-- @name gwaterlib
-- @class library
-- @libtbl gwater_library
SF.RegisterLibrary("gwaterlib")

local function main(instance)
	local gwater_library = instance.Libraries.gwaterlib
	local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
	--- Spawns a GWater particle
	-- @client
	-- @param Vector pos
	-- @param Vector vel
	-- @param number mass
	function gwater_library.spawnParticle(pos, vel, color, mass)
		if LocalPlayer() == instance.player then
			mass = mass ~= nil and mass or 1
			gwater2.solver:SpawnParticle(vunwrap(pos), vunwrap(vel), vunwrap(color):ToColor(), mass)
		end
	end

	function gwater_library.spawnCube(pos, vel, size, apart, color)
		if LocalPlayer() == instance.player then
			gwater2.solver:SpawnCube(vunwrap(pos), vunwrap(vel), vunwrap(size), apart, vunwrap(color):ToColor())
		end
	end

	--- Clears All Gwater
	-- @client
	function gwater_library.clearAllParticles()
		if LocalPlayer() == instance.player then
			gwater2.solver:Reset()
		end
	end

	--- Changes the chosen Gwater parameter.
	-- @client
	-- @param string parameter
	-- @param number value
	function gwater_library.setParameter(parameter, value)
		if LocalPlayer() == instance.player then
			SetGwaterParameter(parameter, value)
		end
	end

	--- Gets the chosen Gwater parameter.
	-- @client
	-- @param string parameter
	-- @return number value
	function gwater_library.getParameter(parameter)
		if LocalPlayer() == instance.player then
			return GetGwaterParameter(parameter)
		end
	end
end

return main
