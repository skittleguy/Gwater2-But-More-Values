AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "GWater2"
ENT.PrintName    = "Transmuter"
ENT.Author       = "Meetric"
ENT.Purpose      = "Turns objects into water"
ENT.Instructions = "Touch it"
ENT.Spawnable    = true
ENT.AdminOnly 	 = true
ENT.RenderGroup = RENDERGROUP_OPAQUE	-- make sure water sees this object

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_phx/construct/glass/glass_plate2x2.mdl")
		self:SetSubMaterial(0, "models/spawn_effect2")
		--self:SetSubMaterial(1, "models/wireframe")
		
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetTrigger(true)

		util.PrecacheModel("models/props_c17/oildrum001.mdl")
	end

	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		local ent = ents.Create(class)
		ent:SetPos(tr.HitPos)
		ent:Spawn()
		ent:Activate()

		return ent
	end

	function ENT:StartTouch(ent)
		if !self:GetTouchTrace().Hit or ent.GWATER2_TOUCHED then return end

		if ent:IsPlayer() then
			ent:KillSilent()
			gwater2.AddModel(gwater2.quick_matrix(ent:GetPos(), nil, Vector(1, 1, 1.5)), "models/props_c17/oildrum001.mdl", {vel = ent:GetVelocity() * FrameTime()})
			return
		end

		local phys = ent:GetPhysicsObject()
		if !IsValid(phys) then return end

		local extra = {
			ent_vel = phys:GetVelocity() * FrameTime(),
			ent_angvel = phys:GetAngleVelocity() * FrameTime()
		}
		local model = ent:GetModel()
		local transform = gwater2.quick_matrix(phys:GetPos(), phys:GetAngles())

		phys:EnableMotion(false)
		ent:SetNotSolid(true)
		ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
		ent.GWATER2_TOUCHED = true
		--ent:Remove()

		-- net is too fast and can explode sometimes
		timer.Simple(0.0, function()
			gwater2.AddModel(transform, model, extra)
			SafeRemoveEntity(ent)
		end)
	end

	ENT.Touch = ENT.StartTouch
end