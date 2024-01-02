#include <BaseVSShader.h>
#include <map>

#include "shaders/GWaterVolumetric_vs30.inc"
#include "shaders/GWaterVolumetric_ps30.inc"

BEGIN_VS_SHADER(GWaterVolumetric, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(SCR_S, SHADER_PARAM_TYPE_VEC3, "[1 1 1]", "Screen Size")
	SHADER_PARAM(DEPTHTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "shadertest/BaseTexture", "Texture of depth")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {

}

SHADER_INIT{
	LoadTexture(DEPTHTEXTURE);
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	SHADOW_STATE {
		unsigned int flags = VERTEX_POSITION | VERTEX_NORMAL | VERTEX_FORMAT_COMPRESSED;
		pShaderShadow->VertexShaderVertexFormat(flags, 1, 0, 0);
		pShaderShadow->EnableTexture(SHADER_SAMPLER0, true);
		pShaderShadow->EnableAlphaTest(IS_FLAG_SET(MATERIAL_VAR_ALPHATEST));

		DECLARE_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	DYNAMIC_STATE {
		// constants
		const float* scr_s = params[SCR_S]->GetVecValue();
		pShaderAPI->SetPixelShaderConstant(0, scr_s);
		
		const float radius = params[RADIUS]->GetFloatValue();
		pShaderAPI->SetPixelShaderConstant(1, &radius);

		BindTexture(SHADER_SAMPLER0, DEPTHTEXTURE, FRAME);

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	Draw();

}

END_SHADER