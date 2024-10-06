local function get_gwater_rt(name, mult, depth) 
	mult = mult or 1
	return GetRenderTargetEx(name, ScrW() * mult, ScrH() * mult,
		RT_SIZE_DEFAULT,
		depth or 0,
		2 + 4 + 8 + 256,
		0,
		IMAGE_FORMAT_RGBA16161616F
	)
end

local cache_screen0 = render.GetScreenEffectTexture()
local cache_screen1 = render.GetScreenEffectTexture(1)
local cache_mipmap = get_gwater_rt("gwater2_mipmap", 1 / 1)
local cache_absorption = get_gwater_rt("gwater2_absorption", 1 / 2, MATERIAL_RT_DEPTH_NONE)
local cache_normals = get_gwater_rt("gwater2_normals", 1 / 1, MATERIAL_RT_DEPTH_SEPARATE)
local cache_blur = get_gwater_rt("gwater2_blur", 1 / 2)
local cache_caustics = GetRenderTargetEx("gwater2_caustics", 512, 512, RT_SIZE_DEFAULT, MATERIAL_RT_DEPTH_SEPARATE, 2 + 4 + 8 + 256, 0, -1)

local water = Material("gwater2/finalpass")
local water_blur = Material("gwater2/smooth")
local water_volumetric = Material("gwater2/volumetric")
local water_normals = Material("gwater2/normals")
local water_bubble = Material("gwater2/bubble")	-- bubbles
local water_mist = Material("gwater2/mist")
local black = Material("gwater2/black")
local cloth = Material("gwater2/cloth")

local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
local blur_scale = CreateClientConVar("gwater2_blur_scale", "1", true)

-- sets up a lighting origin in sourceengine
local function unfuck_lighting(pos0, pos1)
	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)
	render.Model({model = "models/shadertest/envballs.mdl",pos = pos0, angle = EyeAngles()})	-- cubemap
	render.Model({model = "models/shadertest/vertexlit.mdl",pos = pos1, angle = EyeAngles()}) 	-- lighting
	render.OverrideDepthEnable(false, false)
	render.OverrideColorWriteEnable(false, false)
end

local function do_cloth()
	unfuck_lighting(gwater2.cloth_pos, gwater2.cloth_pos)	-- fix cloth lighting, mostly
	render.SetMaterial(cloth)
	gwater2.renderer:DrawCloth()
	render.RenderFlashlights(function() gwater2.renderer:DrawCloth() end)
end

local function do_absorption()
	render.UpdateScreenEffectTexture()	-- _rt_framebuffer is used in refraction shader

	-- depth absorption (disabled when opaque liquids are enabled)
	local _, _, _, a = water:GetVector4D("$color2")
	if water_volumetric:GetFloat("$alpha") != 0 and a > 0 and a < 255 then
		-- ANTIALIAS FIX! (courtesy of Xenthio)
			-- how it works: 
			-- Clear the main rendertarget, keeping depth
			-- Render to main buffer (still has depth), and copy the contents to another rendertarget
			-- Restore the main buffer

		-- clear screen w/o intruding translucents depth buffer
		render.SetMaterial(black)
		render.DrawScreenQuad()

		render.SetMaterial(water_volumetric)
		gwater2.renderer:DrawWater()
		render.CopyTexture(render.GetRenderTarget(), cache_absorption)
		render.DrawTextureToScreen(cache_screen0)
	else
		-- no absorption calculations, so just use solid color
		render.PushRenderTarget(cache_absorption)
		render.Clear(15, 15, 15, 10)
		render.PopRenderTarget()
	end
end

local function do_diffuse_inside()
	-- dont render bubbles underwater if opaque
	local _, _, _, a = water:GetVector4D("$color2")
	if a < 255 then
		-- Bubble particles inside water
		-- Make sure the water screen texture has bubbles but the normal framebuffer does not
		render.SetMaterial(water_bubble)
		render.UpdateScreenEffectTexture(1)
		gwater2.renderer:DrawDiffuse()
		render.CopyTexture(render.GetRenderTarget(), cache_screen0)
		render.DrawTextureToScreen(cache_screen1)
	end
end

local function do_normals()
	local radius = gwater2.solver:GetParameter("radius")

	-- grab normals
	water_normals:SetFloat("$radius", radius)
	render.SetMaterial(water_normals)
	render.PushRenderTarget(cache_normals)
	render.SetRenderTargetEx(1, cache_mipmap)
	render.ClearDepth()
	gwater2.renderer:DrawWater()
	render.PopRenderTarget()
	render.SetRenderTargetEx(1, nil)

	render.SetStencilCompareFunction(STENCIL_EQUAL)

	-- Blur normals
	local scrw = ScrW()
	local scrh = ScrH()

	water_blur:SetFloat("$radius", radius)
	water_blur:SetTexture("$depthtexture", cache_mipmap)
	render.SetMaterial(water_blur)
	for i = 1, blur_passes:GetInt() do
		-- Blur X
		local scale = (0.25 / i) * blur_scale:GetFloat()
		water_blur:SetTexture("$normaltexture", cache_normals)
		water_blur:SetVector("$scrs", Vector(scale / scrw, 0))
		render.PushRenderTarget(cache_blur)
		render.DrawScreenQuad()
		render.PopRenderTarget()
		
		-- Blur Y
		water_blur:SetTexture("$normaltexture", cache_blur)
		water_blur:SetVector("$scrs", Vector(0, scale / scrh))
		render.PushRenderTarget(cache_normals)
		render.DrawScreenQuad()
		render.PopRenderTarget()
	end
end

local lightpos = EyePos()
local function do_finalpass()
	local radius = gwater2.solver:GetParameter("radius")

	-- setup water lighting
	local tr = util.QuickTrace( EyePos(), LocalPlayer():EyeAngles():Forward() * 800, LocalPlayer())
	local dist = math.min(230, (tr.HitPos - tr.StartPos):Length() / 1.5)	
	lightpos = LerpVector(0.8 * FrameTime(), lightpos, EyePos() + (LocalPlayer():EyeAngles():Forward() * dist))	-- fucking hell
	unfuck_lighting(EyePos(), lightpos)	

	-- Setup water material parameters
	water:SetFloat("$radius", radius)
	water:SetTexture("$normaltexture", cache_normals)
	water:SetTexture("$depthtexture", cache_absorption)
	render.SetMaterial(water)
	gwater2.renderer:DrawWater()
	render.RenderFlashlights(function() gwater2.renderer:DrawWater() end)

	render.SetMaterial(water_mist)
	gwater2.renderer:DrawDiffuse()
end

local dist = 2070
flashlight = flashlight or ProjectedTexture()
flashlight:SetTexture("effects/flashlight/square")
flashlight:SetFarZ(dist + 100)
flashlight:SetBrightness(99999)
flashlight:SetEnableShadows(true)
flashlight:SetColor(Color(0, 255, 0, 255))
flashlight:SetFOV(45)
--flashlight:SetNearZ(dist - 100)
local function do_caustics()
	local pos = LocalPlayer():GetPos()
	local offset = Vector(1, 0, 0) * dist
	local ang = (-offset):Angle()
	flashlight:SetPos(pos + offset)
	flashlight:SetAngles(ang)
	flashlight:Update()

	hook.Add("ShouldDrawLocalPlayer", "gwater2_drawplayer", function() return true end)
	render.PushRenderTarget(cache_caustics)
	render.RenderView({
		origin = pos + offset,
		angles = ang,
		fov = 45,
		aspect = 1,
		drawviewmodel = false,
		w = 512,
		h = 512,
	})
	render.PopRenderTarget()
	hook.Remove("ShouldDrawLocalPlayer", "gwater2_drawplayer")
	debugoverlay.Line(pos, pos + offset, 0.1, Color(255, 0, 0, 255))
	debugoverlay.Line(pos + offset, pos + offset + ang:Forward() * 10, 0.1, Color(0, 255, 0, 255))
end

-- gwater2 shader pipeline
hook.Add("PostDrawOpaqueRenderables", "gwater2_render", function(depth, sky, sky3d)	--PreDrawViewModels
	if sky3d or render.GetRenderTarget() then return end	-- STOPS CAUSTICS FROM RECURSIVELY CRASHING

	--do_caustics()
	render.DrawTextureToScreenRect(cache_caustics, 0, 0, 256, 256)

	if gwater2.solver:GetActiveParticles() < 1 then return end
	
	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 255, 0))
	render.ClearRenderTarget(cache_mipmap, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_absorption, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_blur, Color(0, 0, 0, 0))

	gwater2.renderer:SetHang(false)
	gwater2.renderer:BuildMeshes(gwater2.solver, 0.25)

	do_cloth()
	do_absorption()
	do_diffuse_inside()
	do_normals()
	do_finalpass()
	do_caustics()
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)