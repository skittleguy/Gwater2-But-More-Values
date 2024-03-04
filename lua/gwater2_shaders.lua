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

local cache_depth = GetRenderTargetGWater("gwater_cache_depth")
local cache_absorption = GetRenderTargetGWater("gwater_cache_absorption")
local cache_normals = GetRenderTargetGWater("gwater_cache_normals", nil, MATERIAL_RT_DEPTH_SEPARATE)
local cache_bloom = GetRenderTargetGWater("2gwater_cache_bloom", 1 / 2)	-- for blurring
local water_blur = Material("gwater2/smooth")
local water_volumetric = Material("gwater2/volumetric")
local water_normals = Material("gwater2/normals")

-- The code below is the very complicated gwater2 shader pipeline since source doesn't support multiple shaders for one material
local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
local antialias = GetConVar("mat_antialias")
--PreDrawViewModels
hook.Add("PreDrawViewModels", "gwater2_render", function()
	if gwater2.solver:GetCount() < 1 then return end

	-- A rendertargets depth is not written to when anti-aliasing is enabled
	-- I have tried for *weeks* fighting this issue by setting flags, calling C++ functions, and using everything in the cam. library, to no avail.
	-- * 'render.ClearDepth()' does not work well in this case as it makes particles render through walls
	-- * MATERIAL_RT_DEPTH_SEPARATE simply does not work
	-- * '$ignorez' flag on the material works, but has the same issue as 'render.ClearDepth()' (particles render through walls)
	-- My solution at the moment is just force disabling it. I don't have enough time to figure out this problem and frankly I would like to work on other things
	-- Related gmod issues: 
	-- https://github.com/Facepunch/garrysmod-issues/issues/4662
	-- https://github.com/Facepunch/garrysmod-issues/issues/5039
	if antialias:GetInt() > 1 then
		print("[GWater2]: Force disabling MSAA due to RT Depth issues")
		RunConsoleCommand("mat_antialias", 1)
	end
	
	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_depth, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_absorption, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_bloom, Color(0, 0, 0, 0))
	render.UpdateScreenEffectTexture()

	-- cached variables
	local scrw = ScrW()
	local scrh = ScrH()
	local water = gwater2.material
	local radius = gwater2.solver:GetParameter("radius")

	-- Build imeshes for multiple passes
	local up = EyeAngles():Up()
	local right = EyeAngles():Right()
	gwater2.renderer:BuildIMeshes(gwater2.solver, radius * 0.5)
	--render.SetMaterial(Material("models/props_combine/combine_interface_disp"))
	--gwater2.renderer:DrawIMeshes()
	
	-- Depth absorption
	if water_volumetric:GetFloat("$alpha") != 0 then
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
	render.ClearDepth()			-- "fixes" msaa breaking visuals
	gwater2.renderer:DrawIMeshes()
	render.SetRenderTargetEx(0, nil)
	render.SetRenderTargetEx(1, nil)
	
	-- Blur normals
	water_blur:SetFloat("$radius", radius)
	water_blur:SetTexture("$depthtexture", cache_depth)
	render.SetMaterial(water_blur)
	for i = 1, blur_passes:GetInt() do
		-- Blur X
		--local scale = (5 - i) * 0.05
		local scale = 0.05 / i
		water_blur:SetTexture("$normaltexture", cache_normals)	
		water_blur:SetVector("$scrs", Vector(scale / scrw, 0))
		render.SetRenderTarget(cache_bloom)	-- Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.DrawScreenQuad()
		render.SetRenderTarget()
		
		-- Blur Y
		water_blur:SetTexture("$normaltexture", cache_bloom)
		water_blur:SetVector("$scrs", Vector(0, scale / scrh))
		render.SetRenderTarget(cache_normals)
		render.DrawScreenQuad()
		render.SetRenderTarget()
	end

	--render.ClearDepth()

	-- Setup water material parameters
	water:SetFloat("$radius", radius)
	water:SetTexture("$normaltexture", cache_normals)
	water:SetTexture("$screentexture", render.GetScreenEffectTexture())
	water:SetTexture("$depthtexture", cache_absorption)
	render.SetMaterial(water)
	gwater2.renderer:DrawIMeshes()

	-- Debug Draw
	--render.DrawTextureToScreenRect(cache_absorption, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
	render.DrawTextureToScreenRect(cache_normals, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)