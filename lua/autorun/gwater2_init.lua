AddCSLuaFile()

if SERVER then 
	/*local valid_materials = {
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

require((BRANCH == "x86-64" or BRANCH == "chromium" ) and "gwater2" or "gwater2_main")	//carrying
include("gwater2_shaders.lua")	// also carrying

gwater2 = {
	solver = FlexSolver(100000),
	material = Material("gwater2/finalpass"),//Material("vgui/circle"),//Material("sprites/sent_ball"),
	meshes = {},
	color = Color(209, 237, 255, 25),
	update_meshes = function()
		for i = #gwater2.meshes, 1, -1 do
			local prop = gwater2.meshes[i]
			if !prop:IsValid() then
				gwater2.solver:RemoveMesh(i)
				table.remove(gwater2.meshes, i)
				continue
			end

			if prop:GetVelocity() == vector_origin and prop:GetLocalAngularVelocity() == Angle() then continue end
			gwater2.solver:UpdateMesh(i, prop:GetPos(), prop:GetAngles())
		end
	end,
}
gwater2.solver:InitBounds(Vector(-16384, -16384, -16384), Vector(16384, 16384, 16384))	-- source bounds

local volumetric = Material("gwater2/volumetric")
local absorption = CreateClientConVar("gwater2_absorption", "1", true)
-- garry, sincerely... fuck you
timer.Simple(0, function() 
	volumetric:SetFloat("$alpha", absorption:GetBool() and 0.025 or 0)
end)

local function screen_plane(x, y, c)
	return gui.ScreenToVector(x, y):Cross(c)
end

-- tick particle solver
local cm_2_inch = 2.54 * 2.54
local last_systime = os.clock()
local hang_thread = false
local limit_fps = 1 / 60
local average_frametime = limit_fps
local function gwater_tick()
	local systime = os.clock()
	local delta_time = systime - last_systime

	if gwater2.solver:GetCount() == 0 or gwater2.solver:GetParameter("timescale") <= 0 then 
		last_systime = systime
		average_frametime = RealFrameTime() 
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

// run whenever possible, as often as possible. we dont know when flex will finish calculations
local no = function() end
hook.Add("PreRender", "gwater_tick", gwater_tick)
hook.Add("PostRender", "gwater_tick", gwater_tick)
hook.Add("Think", "gwater_tick_collision", gwater2.update_meshes)
hook.Add("Think", "gwater_tick", gwater_tick)

// Add mesh colliders
local function add_prop(ent)
	//do return end
	if !IsValid(ent) or !ent:IsSolid() or ent:IsWeapon() then return end
	//if !IsValid(ent) or (ent:GetClass() != "prop_physics" and !ent:IsPlayer()) then return end
	local phys = ent:GetPhysicsObject()
	if !phys:IsValid() then
		ent:PhysicsInit(SOLID_VPHYSICS)
		local phys = ent:GetPhysicsObject()
		if !phys:IsValid() then return end	// the fuck?
		local convexes = phys:GetMeshConvexes()
		local invalid = #convexes > 10
		for k, v in ipairs(convexes) do 
			if invalid then break end
			invalid = invalid or #v > 64 * 3 
		end

		if !invalid then
			for k, v in ipairs(convexes) do
				gwater2.solver:AddConvexMesh(v, ent:GetPos(), ent:GetAngles())
				table.insert(gwater2.meshes, ent)
			end
		else
			gwater2.solver:AddConcaveMesh(phys:GetMesh(), ent:GetPos(), ent:GetAngles())
			table.insert(gwater2.meshes, ent)
		end
		ent:PhysicsDestroy()
	else
		gwater2.solver:AddConcaveMesh(phys:GetMesh(), ent:GetPos(), ent:GetAngles())
		table.insert(gwater2.meshes, ent)
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

hook.Add("InitPostEntity", "gwater2_addprop", function()
	xpcall(function()
		gwater2.solver:AddMapMesh(game.GetMap())
	end, function(e)
		gwater2.solver:AddConcaveMesh(get_map_vertices(), Vector(), Angle())
		ErrorNoHaltWithStack("[GWater2]: Map BSP structure is unsupported. Reverting to brushes. Collision WILL have holes!")
	end)
	for k, ent in ipairs(ents.GetAll()) do
		add_prop(ent)
	end
end)
hook.Add("OnEntityCreated", "gwater2_addprop", function(ent) timer.Simple(0, function() add_prop(ent) end) end)	// timer.0 so data values are setup correctly