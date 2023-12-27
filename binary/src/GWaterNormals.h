#include <BaseVSShader.h>
#include <map>

#include "shaders/GWaterNormals_vs30.inc"
#include "shaders/GWaterNormals_ps30.inc"

BEGIN_VS_SHADER(GWaterNormals, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(SCR_S, SHADER_PARAM_TYPE_VEC2, "[1 1]", "Screen Size")
	SHADER_PARAM(BASETEXTURE, SHADER_PARAM_TYPE_TEXTURE, 0, "Texture of smoothed normals")
	SHADER_PARAM(SCREENTEXTURE, SHADER_PARAM_TYPE_TEXTURE, 0, "Texture of screen")
	SHADER_PARAM(IOR, SHADER_PARAM_TYPE_FLOAT, "1.333", "Ior of water")
	SHADER_PARAM(ENVMAP, SHADER_PARAM_TYPE_TEXTURE, "env_cubemap", "envmap")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {
	
}

SHADER_INIT{
	if (params[ENVMAP]->IsDefined()) LoadCubeMap(ENVMAP);
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

		DECLARE_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_STATIC_VERTEX_SHADER_COMBO(VERTEXCOLOR, IS_FLAG_DEFINED(MATERIAL_VAR_VERTEXCOLOR));
		SET_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		
		DECLARE_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
	}

	DYNAMIC_STATE {
		// constants
		const float* scr_s = params[SCR_S]->GetVecValue();
		pShaderAPI->SetPixelShaderConstant(0, scr_s);
		
		const float radius = params[RADIUS]->GetFloatValue();
		pShaderAPI->SetPixelShaderConstant(1, &radius);

		const float ior = params[IOR]->GetFloatValue();
		pShaderAPI->SetPixelShaderConstant(2, &ior);

		BindTexture(SHADER_SAMPLER0, BASETEXTURE);
		BindTexture(SHADER_SAMPLER1, SCREENTEXTURE);
		BindTexture(SHADER_SAMPLER2, ENVMAP);
		
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