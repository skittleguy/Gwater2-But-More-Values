#include <BaseVSShader.h>

#include "shaders/GWaterVolumetric_vs30.inc"
#include "shaders/GWaterVolumetric_ps30.inc"

BEGIN_VS_SHADER(GWaterVolumetric, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(ALPHA, SHADER_PARAM_TYPE_VEC3, "0.005", "Alpha")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {

}

SHADER_INIT{

}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	

	SHADOW_STATE {
		unsigned int flags = VERTEX_POSITION | VERTEX_NORMAL | VERTEX_FORMAT_COMPRESSED;
		pShaderShadow->VertexShaderVertexFormat(flags, 1, 0, 0);
		
		// Transparent things (alpha 0 <= x <= 1)
		if (IS_FLAG_SET(MATERIAL_VAR_TRANSLUCENT)) {
			pShaderShadow->EnableDepthWrites(false);
			pShaderShadow->EnableBlending(true);

			// Additive vs multiplicitive
			if (IS_FLAG_SET(MATERIAL_VAR_ADDITIVE)) {
				pShaderShadow->BlendFunc(SHADER_BLEND_SRC_ALPHA, SHADER_BLEND_ONE);
			}
			else {
				pShaderShadow->BlendFunc(SHADER_BLEND_SRC_ALPHA, SHADER_BLEND_ONE_MINUS_SRC_ALPHA);
				//pShaderShadow->BlendFunc(SHADER_BLEND_ONE, SHADER_BLEND_ONE);
			}
		}
		
		// Transparent things (alpha = 0 or alpha = 1)
		pShaderShadow->EnableAlphaTest(IS_FLAG_SET(MATERIAL_VAR_ALPHATEST));

		DECLARE_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	DYNAMIC_STATE {
		// constants
		const float alpha = params[ALPHA]->GetFloatValue();
		const float radius = params[RADIUS]->GetFloatValue();

		pShaderAPI->SetPixelShaderConstant(0, &alpha);
		pShaderAPI->SetPixelShaderConstant(1, &radius);

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	Draw();

}

END_SHADER