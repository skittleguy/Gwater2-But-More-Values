local function screen_plane(x, y, c)
	return gui.ScreenToVector(x, y):Cross(c)
end

local function GetRenderTargetGWater(name, mult, format) 
	mult = mult or 1
	return GetRenderTargetEx(name, ScrW() * mult, ScrH() * mult,
		RT_SIZE_NO_CHANGE,
		0,
		2 + 256,
		0,
		format or IMAGE_FORMAT_RGBA16161616F
	)
end

local cache_depth = GetRenderTargetGWater("gwater_cache_depth")
local cache_absorption = GetRenderTargetGWater("gwater_cache_absorption")
local cache_normals = GetRenderTargetGWater("gwater_cache_normals")
local cache_bloom = GetRenderTargetGWater("4gwater_cache_bloom", 1 / 4)	-- for blurring
local water_blur = Material("gwater2/smooth")
local water_volumetric = Material("gwater2/volumetric")
local water_normals = Material("gwater2/normals")

-- The code below is the very complicated gwater2 shader pipeline since source doesn't support multiple shaders for one material
local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
hook.Add("PreDrawViewModels", "gwater2_render", function()
	
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
	gwater2.solver:BuildIMeshes(EyePos(),
		screen_plane(scrw * 0.5, 0, right), 	-- Top
		screen_plane(scrw * 0.5, scrh, -right), -- Bottom
		screen_plane(0, scrh * 0.5, up),		--Left
		screen_plane(scrw, scrh * 0.5, -up),	-- Right
		gwater2.solver:GetParameter("radius") * 0.5
	)

	-- Depth absorption
	if water_volumetric:GetFloat("$alpha") != 0 then
		render.SetMaterial(water_volumetric)
		render.SetRenderTarget(cache_absorption)
		gwater2.solver:RenderIMeshes()
		render.SetRenderTarget()
		--render.UpdateScreenEffectTexture()
	end

	-- grab normals
	water_normals:SetFloat("$radius", radius * 0.5)
	render.SetMaterial(water_normals)
	render.SetRenderTargetEx(0, cache_normals)
	render.SetRenderTargetEx(1, cache_depth)
	gwater2.solver:RenderIMeshes()
	render.SetRenderTargetEx(0, nil)
	render.SetRenderTargetEx(1, nil)
	
	-- Blur normals
	water_blur:SetTexture("$depthtexture", cache_depth)
	water_blur:SetFloat("$radius", radius)
	render.SetMaterial(water_blur)
	for i = 1, blur_passes:GetInt() do
		-- Blur X
		local scale = (5 - i) * 0.05
		--local scale = 0.05
		water_blur:SetTexture("$normaltexture", cache_normals)	
		water_blur:SetVector("$scrs", Vector(scale / scrw, 0))
		render.SetRenderTarget(cache_bloom)	-- Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.DrawScreenQuad()
		--render.SetRenderTarget()
		
		-- Blur Y
		water_blur:SetTexture("$normaltexture", cache_bloom)
		water_blur:SetVector("$scrs", Vector(0, scale / scrh))
		render.SetRenderTarget(cache_normals)
		render.DrawScreenQuad()
		render.SetRenderTarget()
	end

	-- for some ungodly reason fixes water dissapearing when depth fix is enabled from normals pass (wtf?)
	--render.ClearDepth()
	
	-- Setup water material parameters
	water:SetFloat("$radius", radius * 0.5)
	water:SetVector("$scrs", Vector(scrw, scrh))
	water:SetTexture("$normaltexture", cache_normals)
	water:SetTexture("$screentexture", render.GetScreenEffectTexture())
	water:SetTexture("$depthtexture", cache_absorption)
	render.SetMaterial(water)
	gwater2.solver:RenderIMeshes()

	-- Debug Draw
	render.DrawTextureToScreenRect(cache_absorption, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
	--render.DrawTextureToScreenRect(cache_normals, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)