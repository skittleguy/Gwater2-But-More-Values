// STATIC: "VERTEXCOLOR"			"0..1"

#include "common_vs_fxc.h"

struct VS_INPUT
{
	float4 vPos					: POSITION;		// Position
	float4 vNormal				: NORMAL;		// Normal
	float4 vBoneWeights			: BLENDWEIGHT;	// Skin weights
	float4 vBoneIndices			: BLENDINDICES;	// Skin indices
	float4 vTexCoord			: TEXCOORD0;	// Texture coordinates
	float4 vColor				: COLOR0;		// Color
};

struct VS_OUTPUT
{
	float4 projPosSetup	: POSITION;
	float4 world_coord	: TEXCOORD0;
	float3 world_dir	: TEXCOORD1;
	float3 world_normal	: TEXCOORD2;
	float3 world_depth	: DEPTH0;
	float4 world_color	: COLOR0;
	float3 world_pos	: TEXCOORD3;
};

VS_OUTPUT main( const VS_INPUT v )
{
	VS_OUTPUT o = (VS_OUTPUT)0;

	float3 worldNormal, worldPos;
	SkinPositionAndNormal( 0, v.vPos, v.vNormal, v.vBoneWeights, v.vBoneIndices, worldPos, worldNormal );

	float4 vProjPos = mul( float4( worldPos, 1 ), cViewProj );
	//vProjPos.z = dot( float4( worldPos, 1  ), cViewProjZ );
	o.projPosSetup = vProjPos;
	o.world_depth = float3(vProjPos.z, vProjPos.w, dot(float4(worldPos, 1), cViewProjZ));
	o.world_dir = worldPos - cEyePos;
	o.world_coord = v.vTexCoord;
	o.world_normal = v.vNormal;
	o.world_color = v.vColor;

	o.world_pos = cEyePos;
	return o;
};