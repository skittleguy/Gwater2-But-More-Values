local function screen_plane(x, y, c)
	return gui.ScreenToVector(x, y):Cross(c)
end

local function GetRenderTargetGWater(name, mult, depth) 
	mult = mult or 1
	return GetRenderTargetEx(name, ScrW() * mult, ScrH() * mult,
		RT_SIZE_DEFAULT,
		depth or 0,
		2 + 256,
		0,
		IMAGE_FORMAT_RGBA16161616F
	)
end

local cache_depth = GetRenderTargetGWater("1gwater_cache_depth", 1 / 1)
local cache_absorption = GetRenderTargetGWater("gwater_cache_absorption")
local cache_normals = GetRenderTargetGWater("1gwater_cache_normals", 1 / 1, MATERIAL_RT_DEPTH_SEPARATE)
local cache_bloom = GetRenderTargetGWater("2gwater_cache_bloom", 1 / 2)	-- for blurring
local water_blur = Material("gwater2/smooth")
local water_volumetric = Material("gwater2/volumetric")
local water_normals = Material("gwater2/normals")
local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
local antialias = GetConVar("mat_antialias")

-- rebuild meshes every frame (unused atm since PostDrawOpaque is being a bitch)
--[[
hook.Add("RenderScene", "gwater2_render", function(eye_pos, eye_angles, fov)
	cam.Start3D(eye_pos, eye_angles, fov) -- BuildIMeshes requires a 3d cam context (for frustrum culling)
		gwater2.renderer:BuildIMeshes(gwater2.solver, 1)	
	cam.End3D()
end)]]


-- gwater2 shader pipeline
hook.Add("PreDrawViewModels", "gwater2_render", function(depth, sky, sky3d)	--PreDrawViewModels
	if gwater2.solver:GetActiveParticles() < 1 then return end

	local old_rt = render.GetRenderTarget()

	--if EyePos():DistToSqr(LocalPlayer():EyePos()) > 1 then return end	-- bail if skybox is rendering (used in postdrawopaque)

	-- A rendertargets depth is created separately when anti-aliasing is enabled
	-- In order to have proper rendertarget capture which obeys the depth buffer, we need to use MATERIAL_RT_DEPTH_SHARED.
	-- That way, our rendered particles don't render through walls. (Avoid render.ClearDepth! as it resets this buffer!!!)
	-- Unfortunately MATERIAL_RT_DEPTH_SEPERATE is force enabled when MSAA is on.. 
	-- This texture flag makes it so my shaders can't use the actual depth buffer provided by source. This causes things to render through walls
	-- My solution at the moment is force disabling MSAA, which prevents the issue.
	-- Related gmod issues: 
	-- https://github.com/Facepunch/garrysmod-issues/issues/4662
	-- https://github.com/Facepunch/garrysmod-issues/issues/5039
	-- https://github.com/Facepunch/garrysmod-issues/issues/5367
	-- https://github.com/Facepunch/garrysmod-requests/issues/2308
	if antialias:GetInt() > 1 then
		print("[GWater2]: Force disabling MSAA for technical reasons. (Feel free to ask me (Meetric) for more info)")
		RunConsoleCommand("mat_antialias", 1)
	end

	--[[
	-- diffuse particles
	render.SetMaterial(water_volumetric)//Material("models/wireframe"))
	gwater2.solver:RenderParticles(function(pos, size)
		render.DrawSprite(pos, 5, 5, color_white)
	end)]]

	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_depth, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_absorption, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_bloom, Color(0, 0, 0, 0))
	render.UpdateScreenEffectTexture()	-- _rt_framebuffer is used in refraction shader
	render.OverrideAlphaWriteEnable(true, true)	-- Required for GWater shaders as they use the alpha component

	-- cached variables
	local scrw = ScrW()
	local scrh = ScrH()
	local water = gwater2.material
	local radius = gwater2.solver:GetParameter("radius")

	-- Build imeshes for multiple passes
	local up = EyeAngles():Up()
	local right = EyeAngles():Right()
	gwater2.renderer:BuildIMeshes(gwater2.solver, 1)
	--render.SetMaterial(Material("models/props_combine/combine_interface_disp"))
	--gwater2.renderer:DrawIMeshes()
	
	-- Depth absorption (disabled when opaque liquids are enabled)
	
	local _, _, _, a = water:GetVector4D("$color2")
	if water_volumetric:GetFloat("$alpha") != 0 and a < 255 then
		render.SetMaterial(water_volumetric)
		render.SetRenderTarget(cache_absorption)
		gwater2.renderer:DrawIMeshes()
		render.SetRenderTarget()
	end

	-- grab normals
	water_normals:SetFloat("$radius", radius * 0.5)
	render.SetMaterial(water_normals)
	render.SetRenderTargetEx(0, cache_normals)
	render.SetRenderTargetEx(1, cache_depth)
	render.ClearDepth()
	gwater2.renderer:DrawIMeshes()
	render.SetRenderTargetEx(0, nil)
	render.SetRenderTargetEx(1, nil)
	
	-- Blur normals
	water_blur:SetFloat("$radius", radius * 1.5)
	water_blur:SetTexture("$depthtexture", cache_depth)
	render.SetMaterial(water_blur)
	
	for i = 1, blur_passes:GetInt() do
		-- Blur X
		--local scale = (5 - i) * 0.05
		local scale = 0.25 / i
		water_blur:SetTexture("$normaltexture", cache_normals)	
		water_blur:SetVector("$scrs", Vector(scale / scrw, 0))
		render.SetRenderTarget(cache_bloom)	-- Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.DrawScreenQuad()
		
		-- Blur Y
		water_blur:SetTexture("$normaltexture", cache_bloom)
		water_blur:SetVector("$scrs", Vector(0, scale / scrh))
		render.SetRenderTarget(cache_normals)
		render.DrawScreenQuad()
	end
	render.SetRenderTarget(old_rt)

	-- Setup water material parameters
	water:SetFloat("$radius", radius)
	water:SetTexture("$normaltexture", cache_normals)
	water:SetTexture("$depthtexture", cache_absorption)
	render.SetMaterial(water)
	gwater2.renderer:DrawIMeshes()

	render.OverrideAlphaWriteEnable(false, false)

	-- Debug Draw
	render.DrawTextureToScreenRect(cache_absorption, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
	--render.DrawTextureToScreenRect(cache_normals, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
	--render.DrawTextureToScreenRect(cache_normals, 0, 0, ScrW(), ScrH())
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)