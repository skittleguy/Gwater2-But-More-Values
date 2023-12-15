#include <BaseVSShader.h>
#include <map>

#include "shaders/GWaterNormals_vs30.inc"
#include "shaders/GWaterNormals_ps30.inc"

// Maximum of 4 rts (dx9 limitation)
//ITexture* GWaterNormals_rts[4] = {NULL, NULL, NULL, NULL};

BEGIN_VS_SHADER(GWaterNormals, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, 0, "Radius of particles")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {
	if (!params[RADIUS]->IsDefined()) params[RADIUS]->SetFloatValue(0);
}

SHADER_INIT{
	//LoadTexture(BASETEXTURE, TEXTUREFLAGS_SRGB);
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	SHADOW_STATE {
		unsigned int flags = VERTEX_POSITION | VERTEX_NORMAL | VERTEX_COLOR | VERTEX_FORMAT_COMPRESSED;
		pShaderShadow->VertexShaderVertexFormat(flags, 1, NULL, 0);

		DECLARE_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_STATIC_VERTEX_SHADER_COMBO(VERTEXCOLOR, IS_FLAG_DEFINED(MATERIAL_VAR_VERTEXCOLOR));

		SET_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		
		DECLARE_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
	}

	DYNAMIC_STATE {
		// constants
		float r[1];
		r[0] = params[RADIUS]->GetFloatValue();
		pShaderAPI->SetPixelShaderConstant(0, r);
		
		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
		SET_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
	}
	
	//IMatRenderContext* pMatRenderContext = g_pMaterialSystem->GetRenderContext();

	//for (int i = 0; i < 4; i++) pMatRenderContext->SetRenderTargetEx(i, GWaterNormals_rts[i]);
	
	Draw();

	//for (int i = 0; i < 4; i++) pMatRenderContext->SetRenderTargetEx(i, NULL);

}

END_SHADER