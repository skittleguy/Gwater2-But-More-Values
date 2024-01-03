#include <BaseVSShader.h>

#include "shaders/GWaterNormals_vs30.inc"
#include "shaders/GWaterNormals_ps30.inc"
#include "shaders/GWaterNormalsCheap_ps30.inc"

BEGIN_VS_SHADER(GWaterNormals, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(SCRS, SHADER_PARAM_TYPE_VEC2, "[1 1]", "Screen Size")
	SHADER_PARAM(NORMALTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of smoothed normals")
	SHADER_PARAM(SCREENTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of screen")
	SHADER_PARAM(DEPTHTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Depth texture")
	SHADER_PARAM(IOR, SHADER_PARAM_TYPE_FLOAT, "1.333", "Ior of water")
	SHADER_PARAM(ABSORPTIONMULTIPLIER, SHADER_PARAM_TYPE_FLOAT, "1", "Absorbsion multiplier")
	SHADER_PARAM(REFLECTANCE, SHADER_PARAM_TYPE_FLOAT, "0.01", "Reflectance of water")
	SHADER_PARAM(CHEAP, SHADER_PARAM_TYPE_FLOAT, "1", "Cheapness Enabled/Disabled")
	SHADER_PARAM(ENVMAP, SHADER_PARAM_TYPE_TEXTURE, "env_cubemap", "envmap")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {
	
}

SHADER_INIT {
	LoadCubeMap(ENVMAP);
	LoadTexture(SCREENTEXTURE);
	LoadTexture(NORMALTEXTURE);
	LoadTexture(DEPTHTEXTURE);
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	SHADOW_STATE {

		// Note: Removing VERTEX_COLOR makes the shader work on all objects (Like props)
		unsigned int flags = VERTEX_POSITION | VERTEX_NORMAL | VERTEX_FORMAT_COMPRESSED | VERTEX_COLOR;
		pShaderShadow->VertexShaderVertexFormat(flags, 1, 0, 0);
		pShaderShadow->EnableTexture(SHADER_SAMPLER0, true);	// Smoothed normals texture
		pShaderShadow->EnableTexture(SHADER_SAMPLER1, true);	// Screen texture
		pShaderShadow->EnableTexture(SHADER_SAMPLER2, true);	// Cubemap
		pShaderShadow->EnableTexture(SHADER_SAMPLER3, true);	// Depth

		DECLARE_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterNormals_vs30);

		if (params[CHEAP]->GetFloatValue() == 0) {
			DECLARE_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
			SET_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
		}
		else {
			DECLARE_STATIC_PIXEL_SHADER(GWaterNormalsCheap_ps30);
			SET_STATIC_PIXEL_SHADER(GWaterNormalsCheap_ps30);
		}
	}

	DYNAMIC_STATE {
		// constants
		const float* scr_s = params[SCRS]->GetVecValue();
		float radius = params[RADIUS]->GetFloatValue();
		float ior = params[IOR]->GetFloatValue();
		float reflectance = params[REFLECTANCE]->GetFloatValue();
		
		pShaderAPI->SetPixelShaderConstant(0, scr_s);
		pShaderAPI->SetPixelShaderConstant(1, &radius);
		pShaderAPI->SetPixelShaderConstant(2, &ior);
		pShaderAPI->SetPixelShaderConstant(3, &reflectance);

		BindTexture(SHADER_SAMPLER0, NORMALTEXTURE);
		BindTexture(SHADER_SAMPLER1, SCREENTEXTURE);
		BindTexture(SHADER_SAMPLER2, ENVMAP);
		BindTexture(SHADER_SAMPLER3, DEPTHTEXTURE);
		
		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);

		if (params[CHEAP]->GetFloatValue() == 0) {
			DECLARE_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
			SET_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
		}
		else {
			DECLARE_DYNAMIC_PIXEL_SHADER(GWaterNormalsCheap_ps30);
			SET_DYNAMIC_PIXEL_SHADER(GWaterNormalsCheap_ps30);
		}
	}
	
	Draw();

}

END_SHADER