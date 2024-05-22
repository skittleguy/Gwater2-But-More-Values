AddCSLuaFile()

if SERVER then 
	/*util.AddNetworkString("gwater2_offsetprop")
	local valid_materials = {
        ["floating_metal_barrel"] = true,
        ["wood"] = true,
        ["wood_crate"] = true,
        ["wood_furniture"] = true,
        ["rubbertire"] = true,
        ["wood_solid"] = true,
        ["plastic"] = true,
        ["watermelon"] = true,
        ["default"] = true,
        ["cardboard"] = true,
        ["paper"] = true,
        ["popcan"] = true,
    }
	util.AddNetworkString("gwater2_offsetprop")
	net.Receive("gwater2_offsetprop", function(len, ply)
		local prop = net.ReadEntity()
		local pos = net.ReadVector()
		local vel = net.ReadVector()
		local num = net.ReadInt(8)

		local phys = prop:GetPhysicsObject()
		if phys:IsValid() then
			vel = vel * math.sqrt(phys:GetMass())
			if valid_materials[phys:GetMaterial()] then
				if vel:Dot(Vector(0, 0, 1)) > 0 then 
					vel = vel + Vector(0, 0, num * phys:GetMass() * 0.5) 
				end
				//vel = vel + Vector(0, 0, num * 0.3)
				phys:SetAngleVelocity(phys:GetAngleVelocity() * 0.9)
				//phys:SetVelocity(phys:GetVelocity() * 0.9)
			end
			phys:ApplyForceOffset(vel, pos)
			//phys:SetAngleVelocity(phys:GetAngleVelocity() * 0.9)
			//phys:SetVelocity(phys:GetVelocity() * 0.99)
		end
	end)*/

	return 
end

-- GetMeshConvexes but for client
local function unfucked_get_mesh(ent, raw)
	-- Physics object exists
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then return phys:GetMesh() end

	local model = ent:GetModel()
	local is_ragdoll = util.IsValidRagdoll(model)
	local convexes

	if !is_ragdoll or raw then
		local cs_ent = ents.CreateClientProp(model)
		local phys = cs_ent:GetPhysicsObject()
		convexes = phys:IsValid() and (raw and phys:GetMesh() or phys:GetMeshConvexes())
		cs_ent:Remove()
	else 
		local cs_ent = ClientsideRagdoll(model)
		convexes = {}
		for i = 0, cs_ent:GetPhysicsObjectCount() - 1 do
			table.insert(convexes, cs_ent:GetPhysicsObjectNum(i):GetMesh())
		end
		cs_ent:Remove()
	end

	return convexes
end

-- adds entity to FlexSolver
local function add_prop(ent)
	if !IsValid(ent) or !ent:IsSolid() or ent:IsWeapon() or !ent:GetModel() then return end

	local convexes = unfucked_get_mesh(ent)
	if !convexes then return end

	if #convexes < 16 then	-- too many convexes to be worth calculating
		for k, v in ipairs(convexes) do
			if #v <= 64 * 3 then	-- hardcoded limits.. No more than 64 planes per convex as it is a FleX limitation
				gwater2.solver:AddConvexMesh(ent:EntIndex(), v, ent:GetPos(), ent:GetAngles())
				print("adding convex mesh")
			else
				gwater2.solver:AddConcaveMesh(ent:EntIndex(), v, ent:GetPos(), ent:GetAngles())
				print("adding concave mesh")
			end
		end
	else
		gwater2.solver:AddConcaveMesh(ent:EntIndex(), unfucked_get_mesh(ent, true), ent:GetPos(), ent:GetAngles())
		print("adding concave mesh")
	end

end

local function get_map_vertices()
	local all_vertices = {}
	for _, brush in ipairs(game.GetWorld():GetBrushSurfaces()) do
		local vertices = brush:GetVertices()
		for i = 3, #vertices do
			all_vertices[#all_vertices + 1] = vertices[1]
			all_vertices[#all_vertices + 1] = vertices[i - 1]
			all_vertices[#all_vertices + 1] = vertices[i]
		end
	end

	return all_vertices
end

require((BRANCH == "x86-64" or BRANCH == "chromium" ) and "gwater2" or "gwater2_main")	-- carrying
include("gwater2_shaders.lua")	-- also carrying

gwater2 = {
	solver = FlexSolver(100000),
	renderer = FlexRenderer(),
	material = Material("gwater2/finalpass"),--Material("vgui/circle"),--Material("sprites/sent_ball"),
	update_meshes = function(index, id, rep)
		if id == 0 then return end

		local ent = Entity(id)
		if !IsValid(ent) then 
			gwater2.solver:RemoveMesh(id)
		else 
			if !util.IsValidRagdoll(ent:GetModel()) then
				gwater2.solver:UpdateMesh(index, ent:GetPos(), ent:GetAngles())	
			else
				-- horrible code for proper ragdoll collision. Still breaks half the time. Fuck source
				local bone_index = ent:TranslatePhysBoneToBone(rep)
				local pos, ang = ent:GetBonePosition(bone_index)
				if !pos or pos == ent:GetPos() then 	-- wtf?
					local bone = ent:GetBoneMatrix(bone_index)
					if bone then
						pos = bone:GetTranslation()
						ang = bone:GetAngles()
					else
						pos = ent:GetPos()
						ang = ent:GetAngles()
					end
				end
				gwater2.solver:UpdateMesh(index, pos, ang)
			end
		end
	end,
	reset_solver = function(err)
		xpcall(function()
			gwater2.solver:AddMapMesh(0, game.GetMap())
		end, function(e)
			gwater2.solver:AddConcaveMesh(0, get_map_vertices(), Vector(), Angle())
			if !err then
				ErrorNoHaltWithStack("[GWater2]: Map BSP structure is unsupported. Reverting to brushes. Collision WILL have holes!")
			end
		end)

		for k, ent in ipairs(ents.GetAll()) do
			add_prop(ent)
		end

		gwater2.solver:InitBounds(Vector(-16384, -16384, -16384), Vector(16384, 16384, 16384))	-- source bounds
	end
}

-- tick particle solver
local cm_2_inch = 2.54 * 2.54
local last_systime = os.clock()
local hang_thread = false
local limit_fps = 1 / 60
local average_frametime = limit_fps
local function gwater_tick()
	local systime = os.clock()
	local delta_time = systime - last_systime

	if gwater2.solver:GetActiveParticles() == 0 or gwater2.solver:GetParameter("timescale") <= 0 then 
		last_systime = systime
		average_frametime = RealFrameTime()	-- internally clamped to minimum of 10 fps
		return 
	elseif hang_thread and delta_time < limit_fps then
		return
	end

	if gwater2.solver:Tick(average_frametime * cm_2_inch, hang_thread and 0 or 1) then
	//if gwater2.solver:Tick(1/165 * cm_2_inch, hang_thread and 0 or 1) then
		average_frametime = average_frametime + ((systime - last_systime) - average_frametime) * 0.03
		last_systime = systime	// smooth out fps
	end
end

local function gwater_tick2()
	--if gwater2.solver:GetActiveParticles() == 0 or gwater2.solver:GetParameter("timescale") <= 0 then return end

	gwater2.solver:Tick(limit_fps * cm_2_inch, 0)
end

// run whenever possible, as often as possible. we dont know when flex will finish calculations
local no = function() end
hook.Add("PreRender", "gwater_tick", no)
hook.Add("PostRender", "gwater_tick", no)
hook.Add("Think", "gwater_tick", function()
	--gwater2.solver:IterateMeshes(gwater2.update_meshes)
end)

timer.Create("gwater2_tick", limit_fps, 0, function()
	gwater2.solver:IterateMeshes(gwater2.update_meshes)
	gwater_tick2()
end)
gwater2.reset_solver()
hook.Add("InitPostEntity", "gwater2_addprop", gwater2.reset_solver)
hook.Add("OnEntityCreated", "gwater2_addprop", function(ent) timer.Simple(0, function() add_prop(ent) end) end)	// timer.0 so data values are setup correctly