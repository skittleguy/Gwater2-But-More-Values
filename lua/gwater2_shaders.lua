local function screen_plane(x, y, c)
	return gui.ScreenToVector(x, y):Cross(c)
end

if !EGSM or !(EGSM.Version > 0) then 
	print("[GWater2 Internal Error]: Failed to load shader base (is EGSM installed correctly?)")
	hook.Add("PreDrawViewModels", "gwater_particle", function()
		// Render particles (sprites) & calculate normals
		--render.SetMaterial(gwater2.material)
		render.SetMaterial(Material("gwater2/particle2"))
		local up = EyeAngles():Up()
		local right = EyeAngles():Right()
		local scrw = ScrW()
		local scrh = ScrH()
		render.OverrideDepthEnable(true, true)
		gwater2.particles = gwater2.solver:RenderPositionsExternal2(EyePos(),
			screen_plane(scrw * 0.5, 0, right), 	// Top
			screen_plane(scrw * 0.5, scrh, -right), // Bottom
			screen_plane(0, scrh * 0.5, up),	// Left
			screen_plane(scrw, scrh * 0.5, -up),	// Right
			gwater2.solver:GetParameter("radius") * 0.75	// Radius
		)
		render.OverrideDepthEnable(false, false)
	end)
	return 
else
	print("[GWater2]: EGSM Loaded successfully")
end

shaderlib.CompileVertexShader("GWaterParticleVertex", 0, file.Read("shaders/gwater_vertex.hlsl", "LUA"))
shaderlib.CompileVertexShader("GWaterParticleVertexLite", 0, file.Read("shaders/gwater_vertex_lite.hlsl", "LUA"))
shaderlib.CompilePixelShader("GWaterParticleNormalsPixel", 0, file.Read("shaders/gwater_normals.hlsl", "LUA"))
shaderlib.CompilePixelShader("GWaterParticleSmoothPixel", 0, file.Read("shaders/gwater_smooth.hlsl", "LUA"))
shaderlib.CompilePixelShader("GWaterParticleFinalPixel", 0, file.Read("shaders/gwater_finalpass.hlsl", "LUA"))

local function GetRenderTargetGWater(name, mult, format) 
	format = format or IMAGE_FORMAT_RGBA16161616F	// 16F allows for negative values
	mult = mult or 1
	return GetRenderTargetEx(name, ScrW() * mult, ScrH() * mult,
		RT_SIZE_NO_CHANGE,
		0,
		2 + 256,
		0,
		format
	)
end

local cache_dir = GetRenderTargetGWater("gwater_cache_dir")
local cache_normals = GetRenderTargetGWater("gwater_cache_normals")
local cache_bloom = GetRenderTargetGWater("gwater_cache_bloom", 1 / 4)	// quarter resolution for blurring
local cache_depth = GetRenderTargetGWater("gwater_cache_depth", nil, IMAGE_FORMAT_RGBA16161616)

// Create normals shader
local particle = shaderlib.NewShader("GWaterParticleNormals")
particle:SetVertexShader("GWaterParticleVertex")
particle:SetPixelShader("GWaterParticleNormalsPixel")
particle:SetRenderTarget(1, cache_normals:GetName())
particle:SetRenderTarget(2, cache_dir:GetName())
particle:SetRenderTarget(3, cache_depth:GetName())
local param = particle:AddParam("$radius", SHADER_PARAM_TYPE_FLOAT)
particle:SetPixelShaderConstantFP(0, param)
local mat_table = {["$ignorez"] = 1, ["$envmap"] = "env_cubemap"}

// Create smooth shader
local particle_smooth = shaderlib.NewShader("GWaterParticleSmooth")
particle_smooth:SetVertexShader("GWaterParticleVertexLite")
particle_smooth:SetPixelShader("GWaterParticleSmoothPixel")
particle_smooth:BindTexture(0, PARAM_BASETEXTURE)
local param = particle_smooth:AddParam("$depthtexture", SHADER_PARAM_TYPE_TEXTURE)
particle_smooth:BindTexture(1, param)
local param = particle_smooth:AddParam("$size", SHADER_PARAM_TYPE_VEC2)
particle_smooth:SetPixelShaderConstantFP(0, param)
local mat_blur = CreateMaterial("gwater_particle_smooth", "GWaterParticleSmooth", mat_table)	// Material which uses smooth normal shader

// Create final pass shader
local particle_final = shaderlib.NewShader("GWaterParticleFinal")
particle_final:SetVertexShader("GWaterParticleVertexLite")
particle_final:SetPixelShader("GWaterParticleFinalPixel")
particle_final:BindTexture(0, PARAM_BASETEXTURE)
local param = particle_final:AddParam("$directiontexture", SHADER_PARAM_TYPE_TEXTURE)
particle_final:BindTexture(1, param)
local param = particle_final:AddParam("$normaltexture", SHADER_PARAM_TYPE_TEXTURE)
particle_final:BindTexture(2, param)
local param = particle_final:AddParam("$depthtexture", SHADER_PARAM_TYPE_TEXTURE)
particle_final:BindTexture(3, param)
local param = particle_final:AddParam("$envmap", SHADER_PARAM_TYPE_TEXTURE)
particle_final:SetFlags2(MATERIAL_VAR2_USES_ENV_CUBEMAP)
particle_final:BindCubeMap(4, param)
particle_final:SetPixelShaderStandardConstant(PSREG_AMBIENT_CUBE, STDCONST_AMBIENT_CUBE)
local mat_final = CreateMaterial("gwater_particle_final", "GWaterParticleFinal", mat_table)	// Material which uses final pass shader

// Render smoothed particles & display onscreen
local black = Color(0, 0, 0, 0)
hook.Add("PreRender", "gwater_sky", function() 
	// dammit egsm
	hook.Remove("PreDrawViewModel", "!!!EGSM_ImTooLazy")
	hook.Remove("NeedsDepthPass", "!!!EGSM_ImTooLazy")
	hook.Remove("PostDraw2DSkybox", "!!!EGSM_ImTooLazy")
end)
hook.Add("PreDrawViewModels", "gwater_particle", function()

	// Update RTs
	render.UpdateScreenEffectTexture()
	render.ClearRenderTarget(cache_normals, black)
	render.ClearRenderTarget(cache_dir, black)
	render.ClearRenderTarget(cache_bloom, black)
	render.ClearRenderTarget(cache_depth, black)
	
	// Render particles (sprites) & calculate normals
	render.SetMaterial(gwater2.material)
	gwater2.material:SetFloat("$radius", gwater2.solver:GetParameter("radius"))
	local up = EyeAngles():Up()
	local right = EyeAngles():Right()
	local scrw = ScrW()
	local scrh = ScrH()
	render.OverrideDepthEnable(true, true)
	gwater2.particles = gwater2.solver:RenderPositionsExternal2(EyePos(),
		screen_plane(scrw * 0.5, 0, right), 	// Top
		screen_plane(scrw * 0.5, scrh, -right), // Bottom
		screen_plane(0, scrh * 0.5, up),	// Left
		screen_plane(scrw, scrh * 0.5, -up),	// Right
		gwater2.solver:GetParameter("radius")	// Radius
	)
	render.OverrideDepthEnable(false, false)

	// Debug
	//render.DrawTextureToScreenRect(render.GetScreenEffectTexture(), ScrW() * 0.75, 0, ScrW() / 4, ScrH() / 4)
	//render.DrawTextureToScreenRect(cache_depth, ScrW() * 0.75, ScrH() * 0.25, ScrW() / 4, ScrH() / 4)
	//render.DrawTextureToScreenRect(cache_normals, 0, 0, ScrW() / 4, ScrH() / 4)
	//render.DrawTextureToScreenRect(cache_dir, 0, ScrH() * 0.5, ScrW() / 4, ScrH() / 4)

	
	// Smooth normals
	mat_blur:SetTexture("$depthtexture", cache_depth)
	for i = 1, 2 do
		// Blur X
		mat_blur:SetTexture("$basetexture", cache_normals)	
		mat_blur:SetVector("$size", Vector(0, 0.1))
		render.SetRenderTarget(cache_bloom)	// Bloom texture resolution is significantly lower than screen res, enabling for a faster blur
		render.SetMaterial(mat_blur)
		render.DrawScreenQuad()
		render.SetRenderTarget()

		//render.DrawTextureToScreenRect(cache_bloom, 0, ScrH() / 4, ScrW() / 4, ScrH() / 4)

		// Blur Y
		mat_blur:SetTexture("$basetexture", cache_bloom)
		mat_blur:SetVector("$size", Vector(0.1, 0))
		render.SetRenderTarget(cache_normals)
		render.SetMaterial(mat_blur)
		render.DrawScreenQuad()
		render.SetRenderTarget()
	end

	// Debug
	//render.DrawTextureToScreenRect(cache_normals, 0, ScrH() / 4, ScrW() / 4, ScrH() / 4)

	// Final draw
	mat_final:SetTexture("$basetexture", render.GetScreenEffectTexture())	// framebuffer before particle rendering
	mat_final:SetTexture("$depthtexture", cache_depth)	// depth buffer (including ddx/ddy)
	mat_final:SetTexture("$normaltexture", cache_normals)	// smoothed normals
	mat_final:SetTexture("$directiontexture", cache_dir)	// direction of eye to particle
	render.SetMaterial(mat_final)
	render.DrawScreenQuad()
end)