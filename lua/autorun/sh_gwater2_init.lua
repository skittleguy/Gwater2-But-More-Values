AddCSLuaFile()

//do return end
if SERVER then 
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
	end)

	return 
end

require("gwater2")	//carrying
include("gwater2_shaders.lua")	// also carrying

gwater2 = {
	solver = FlexSolver(100000),
	material = Material("gwater2/particle2"),//Material("vgui/circle"),//Material("sprites/sent_ball"),
	particles = 0,
	meshes = {},
	update_meshes = function()
		for i = #gwater2.meshes, 1, -1 do
			local prop = gwater2.meshes[i]
			if !prop:IsValid() then
				gwater2.solver:RemoveMesh(i)	// C++ is 0 indexed, but World is at 1
				table.remove(gwater2.meshes, i)
				continue
			end

			if prop:GetVelocity() == vector_origin and prop:GetLocalAngularVelocity() == Angle() then continue end
			gwater2.solver:UpdateMesh(i, prop:GetPos(), prop:GetAngles())
		end
	end,
}

// Draw particles
local draw_sprite = render.DrawSprite
local sprite_size = 10
local function draw_particles(pos)
	draw_sprite(pos, sprite_size, sprite_size, color_white)
end
local function screen_plane(x, y, c)
	return gui.ScreenToVector(x, y):Cross(c)
end

// Simulate particles
local cm_2_inch = 2.54 * 2.54
local last_systime = os.clock()
local average_frametime = 0
local hang_thread = false
local limit_fps = 1 / 60
local function gwater_tick()
	local systime = os.clock()
	local delta_time = systime - last_systime

	if gwater2.solver:GetCount() == 0 then 
		last_systime = systime
		average_frametime = RealFrameTime() 
		return 
	elseif hang_thread and delta_time < limit_fps then
		return
	end
	
	if gwater2.solver:Tick(average_frametime * cm_2_inch, hang_thread and 0 or 1) then
	//if gwater2.solver:Tick(1/165 * cm_2_inch, hang_thread and 0 or 1) then
		average_frametime = average_frametime + ((systime - last_systime) - average_frametime) / 30
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
	//if !IsValid(ent) or !ent:IsSolid() or ent:IsWeapon() or ent:IsPlayer() then return end
	if !IsValid(ent) or (ent:GetClass() != "prop_physics" and !ent:IsPlayer()) then return end
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
				gwater2.solver:AddConvexMesh(v, ent:GetPos(), ent:GetAngles(), ent:OBBMins(), ent:OBBMaxs())
				table.insert(gwater2.meshes, ent)
			end
		else
			gwater2.solver:AddConcaveMesh(phys:GetMesh(), ent:GetPos(), ent:GetAngles(), ent:OBBMins(), ent:OBBMaxs())
			table.insert(gwater2.meshes, ent)
		end
		ent:PhysicsDestroy()
	else
		gwater2.solver:AddConcaveMesh(phys:GetMesh(), ent:GetPos(), ent:GetAngles(), ent:OBBMins(), ent:OBBMaxs())
		table.insert(gwater2.meshes, ent)
	end
end

//hook.Add("InitPostEntity", "gwater2_addprop", function()
	gwater2.solver:AddMapMesh(game.GetMap())
	for k, ent in ipairs(ents.GetAll()) do
		add_prop(ent)
	end
//end)
hook.Add("OnEntityCreated", "gwater2_addprop", function(ent) timer.Simple(0, function() add_prop(ent) end) end)	// timer.0 so data values are setup correctly

for k, ent in ipairs(ents.GetAll()) do
	add_prop(ent)
end

// Simple interface
local avg = 0
local line = 0
local lines = {}
hook.Add("HUDPaint", "gwater2_interact", function()
	local lp = LocalPlayer()
	local active = lp:GetActiveWeapon()
	if !IsValid(active) or active:GetClass() != "weapon_crowbar" then return end

	if lp:KeyDown(IN_ATTACK2) then
		local forward = LocalPlayer():EyeAngles():Forward()
		local sprite_size = gwater2.solver:GetParameter("radius")
			gwater2.solver:SpawnCube(LocalPlayer():EyePos() + forward * sprite_size * 4 * 5, forward * 100, Vector(4, 4, 4), sprite_size)
			//for _ = 1, 10 do
			//	gwater2.solver:SpawnParticle(
			//		LocalPlayer():EyePos() + forward * sprite_size * 5 + VectorRand(-10, 10), 
			//		forward * 100, 
			//		HSVToColor(CurTime() * 10 % 360, 1, 1),
			//		//Color(80, math.random() * 50 + 100, math.random() * 100 + 150, 180), 
			//		//Color(math.random() * 20 + 70, math.random() * 20 + 50, 5, 250), 
			//		//Color(128, 0, 0, 255),
			//		1
			//	)
			//end
	elseif lp:KeyDown(IN_RELOAD) then
		gwater2.solver:Reset()
	end
	draw.DrawText(gwater2.particles, "CloseCaption_Normal", ScrW() * 0.5, ScrH() * 0.5 - 30, color_white, TEXT_ALIGN_CENTER)

/*
	surface.SetDrawColor(0, 255, 0, 255)
	avg = avg + (RealFrameTime() - avg) * 0.01

	lines[line] = -(6 / avg) + 1080
	for i = 0, 1920 do

		if !lines[i - 1] or !lines[i] then continue end
		surface.DrawLine(i * 1, lines[i - 1], i * 1 + 1, lines[i])
	end
	
	
	line = (line + 1) % 1920*/
end)