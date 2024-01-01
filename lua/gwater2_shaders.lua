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
local cache_bloom = GetRenderTargetGWater("4gwater_cache_bloom", 1 / 4)	-- quarter resolution for blurring

local water_blur = Material("gwater2/smooth")
local rt_mat = CreateMaterial("gwater2_rtmat", "UnlitGeneric", {
	["$ignorez"] = 1,
})

-- used because normals are a frame behind
local screen_planes = {vector_origin, vector_origin, vector_origin, vector_origin}
local function s2v(x, y)	-- screen to vector + eye position
	return EyePos() + gui.ScreenToVector(x, y) * 1000
end

local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
hook.Add("PreDrawViewModels", "gwater_particle", function()
	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))
	render.UpdateScreenEffectTexture()

	-- temporal reproject normals from last frame, incase we have moved in that time..
	rt_mat:SetTexture("$basetexture", cache_normals2)
	render.SetRenderTarget(cache_normals)
	render.SetMaterial(rt_mat)
	render.DrawQuad(unpack(screen_planes))
	render.SetRenderTarget()

	render.CopyTexture(cache_normals, cache_normals2)
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))

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

	--render.OverrideDepthEnable(true, false)
	gwater2.particles = gwater2.solver:RenderParticlesExternal2(EyePos(),
		screen_plane(scrw * 0.5, 0, right), 	-- Top
		screen_plane(scrw * 0.5, scrh, -right), -- Bottom
		screen_plane(0, scrh * 0.5, up),		--Left
		screen_plane(scrw, scrh * 0.5, -up),	-- Right
		radius * 0.5
	)
	--render.OverrideDepthEnable(false, false)
	render.SetRenderTargetEx(1, nil)
	render.SetRenderTargetEx(2, nil)

	-- Blur normals
	render.ClearRenderTarget(cache_bloom, Color(0, 0, 0, 0))
	water_blur:SetTexture("$depthtexture", cache_depth)
	water_blur:SetFloat("$radius", radius)
	render.SetMaterial(water_blur)
	for i = 1, blur_passes:GetInt() do
		-- Blur X
		local scale = (5 - i) * 0.05
		--local scale = 0.05
		water_blur:SetTexture("$basetexture", cache_normals)	
		--water_blur:SetTexture("$depthtexture", cache_depth)
		water_blur:SetVector("$scr_s", Vector(scale / ScrW(), 0))
		render.SetRenderTarget(cache_bloom)	-- Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.DrawScreenQuad()
		render.SetRenderTarget()
		
		-- Blur Y
		water_blur:SetTexture("$basetexture", cache_bloom)
		--water_blur:SetTexture("$depthtexture", cache_bloom)
		water_blur:SetVector("$scr_s", Vector(0, scale / ScrH()))
		render.SetRenderTarget(cache_normals)
		--render.SetRenderTarget(cache_depth)
		render.DrawScreenQuad()
		render.SetRenderTarget()
	end
	--render.CopyTexture(cache_depth, cache_normals2)
	render.CopyTexture(cache_normals, cache_normals2)

	-- for temporal reprojection
	screen_planes = {s2v(0, 0), s2v(ScrW(), 0), s2v(ScrW(), ScrH()), s2v(0, ScrH())}

	-- Debug Draw
	render.DrawTextureToScreenRect(cache_normals2, ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)