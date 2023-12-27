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
local cache_normals = GetRenderTargetGWater("gwater_cache_normals")
local cache_normals2 = GetRenderTargetGWater("gwater_cache_normals2")
local cache_bloom = GetRenderTargetGWater("gwater_cache_bloom", 1 / 2)	// quarter resolution for blurring

local water_blur = CreateMaterial("gwater_smooth", "GWaterSmooth", {
	["$ignorez"] = 1,
})

hook.Add("PreDrawViewModels", "gwater_particle", function()
	render.UpdateScreenEffectTexture()

	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_depth, Color(0, 0, 0, 0))

	-- cached variables
	local scrw = ScrW()
	local scrh = ScrH()
	local water = gwater2.material
	local radius = gwater2.solver:GetParameter("radius")

	-- Setup water material parameters
	water:SetFloat("$radius", radius)
	water:SetVector("$scr_s", Vector(scrw, scrh))
	water:SetTexture("$basetexture", cache_normals2)
	water:SetTexture("$screentexture", render.GetScreenEffectTexture())
	--water:SetTexture("$depthtexture", render.GetFullScreenDepthTexture())
	render.SetRenderTargetEx(1, cache_normals)
	render.SetRenderTargetEx(2, cache_depth)
	render.SetMaterial(water)

	-- Render particles
	local up = EyeAngles():Up()
	local right = EyeAngles():Right()

	//render.OverrideDepthEnable(true, false)
	gwater2.particles = gwater2.solver:RenderParticlesExternal2(EyePos(),
		screen_plane(scrw * 0.5, 0, right), 	// Top
		screen_plane(scrw * 0.5, scrh, -right), // Bottom
		screen_plane(0, scrh * 0.5, up),	// Left
		screen_plane(scrw, scrh * 0.5, -up),	// Right
		radius * 0.5
	)
	//render.OverrideDepthEnable(false, false)
	render.SetRenderTargetEx(1, nil)
	render.SetRenderTargetEx(2, nil)

	-- Blur normals
	water_blur:SetTexture("$depthtexture", cache_depth)
	water_blur:SetFloat("$radius", radius)
	render.SetMaterial(water_blur)
	for i = 1, 3 do
		// Blur X
		local scale = (4 - i) * 0.05
		--local scale = 0.2
		water_blur:SetTexture("$basetexture", cache_normals)	
		--water_blur:SetTexture("$depthtexture", cache_depth)
		water_blur:SetVector("$scr_s", Vector(0, scale / ScrH()))
		render.SetRenderTarget(cache_bloom)	-- Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.DrawScreenQuad()

		// Blur Y
		water_blur:SetTexture("$basetexture", cache_bloom)
		--water_blur:SetTexture("$depthtexture", cache_bloom)
		water_blur:SetVector("$scr_s", Vector(scale / ScrW(), 0))
		render.SetRenderTarget(cache_normals)
		render.DrawScreenQuad()
		render.SetRenderTarget()
	end
	--render.CopyTexture(cache_depth, cache_normals2)
	render.CopyTexture(cache_normals, cache_normals2)

	-- Debug Draw
	render.DrawTextureToScreenRect(cache_depth, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- Fixes npcs and stuff dissapearing, not 100% sure why it works
--	return true
--end)