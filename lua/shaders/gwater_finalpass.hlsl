#include "common_fxc.h"
#include "shader_constant_register_map.h"
#include "common_vertexlitgeneric_dx9.h"

sampler FrameBuffer	 	: register(s0);
sampler DirectionBuffer : register(s1);
sampler NormalBuffer  	: register(s2);
sampler DepthBuffer 	: register(s3);
samplerCUBE Cubemap		: register(s4);
const float3 cAmbientCube[6] : register(PSREG_AMBIENT_CUBE);

#define PI 3.1415926535897932384626433832795

struct PS_INPUT {
	float2 P 			: VPOS;
	float2 world_coord	: TEXCOORD0;
};

float3 HUEtoRGB(in float H) {
	float R = abs(H * 6 - 3) - 1;
	float G = 2 - abs(H * 6 - 2);
	float B = 2 - abs(H * 6 - 4);
	return saturate(float3(R,G,B));
}

float3 HSVtoRGB(in float3 HSV) {
	float3 RGB = HUEtoRGB(HSV.x);
	return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

float random(in float2 uv) {
    float2 noise = (frac(sin(dot(uv ,float2(12.9898,78.233)*2.0)) * 43758.5453));
    return abs(noise.x + noise.y) * 0.5;
}

float fresnelSchlicks(float3 incident, float3 normal, float ior) {
    float f0 = (ior - 1.0) / (ior + 1.0);
    f0 *= f0;
    return f0 + (1.0 - f0) * pow(1.0 - max(dot(incident, normal), 0), 5.0);
}

float G1V(float dnv, float k){
    return 1.0 / (dnv * (1.0 - k) + k);
}


float ggx(float3 normal, float3 incident, float3 lightDirection, float rough, float f0){
    float alpha = rough * rough;
    float3 h = normalize(incident + lightDirection);
    float dnl = clamp(dot(normal, lightDirection), 0.0, 1.0);
    float dnv = clamp(dot(normal, incident), 0.0, 1.0);
    float dnh = clamp(dot(normal, h), 0.0, 1.0);
    float dlh = clamp(dot(lightDirection, h), 0.0, 1.0);
    float f, d, vis;
    float asqr = alpha * alpha;
    float den = dnh * dnh * (asqr - 1.0) + 1.0;
    d = asqr / (PI * den * den);
    dlh = pow(1.0 - dlh, 5.0);
    f = f0 + (1.0 - f0) * dlh;
    float k = alpha / 1.0;
    vis = G1V(dnl, k) * G1V(dnv, k);
    float spec = dnl * d * f * vis;
    return spec;
}

float3 lerp_color(float3 a, float3 b, float thru) {
	return (a + b * thru);
}

float4 main(PS_INPUT i) : COLOR {
	//if ((i.P.x + i.P.y) % 2 == 0) discard;	// Dithering (half trasparent) test
	// Depth check
	
	float4 depth = tex2D(DepthBuffer, i.world_coord);
	if (depth.w != 1) discard;
	
	float3 final_direction = tex2D(DirectionBuffer, i.world_coord);
	float3 final_normal = tex2D(NormalBuffer, i.world_coord); 
	float3 sun_dir = float3(-0.234736, 0.441474, 0.866025);

	// BLOOD: float4(0.3,0,0.005,0.95) SHIT: float4(0.1,0.02,0,0) BLUE GEL: float4(0,0.2,1,0) ORANGE GEL: float4(1,0.2,0,0) OLD WATER: float3(0.280621, 0.721494, 0.775833);
	// RADIATION: float4(0.1, 1, 0.1) WATER: float4(0.5, 0.8, 1, 1.0) SILVER: float4(0.4, 0.4, 0.4, 0) JELLO: float4(0.6,0,0.005,1)
	//float3 water_color = float3(0.8, 0.9, 1.0);
	float3 water_color = float3(0.5, 0.8, 1.0);

	float3 reflection = reflect(final_direction, final_normal);
	float fresnel = fresnelSchlicks(reflection, final_normal, 1.33);

	float phong = ggx(-final_normal, final_direction, -sun_dir, 0.2, fresnel);
	float3 specular = texCUBE(Cubemap, reflection).xyz * fresnel;
	float lambert = dot(final_normal, sun_dir) * 0.45 + 0.55;
	
	float the_dot = pow(max(1 - dot(final_direction, -final_normal), 0), 1) + 0.5;
	float3 frame_color = tex2D(FrameBuffer, i.world_coord + final_normal.xy / SCR_S * 50) * lerp(float3(1, 1, 1), water_color, min(the_dot, 1));
	//float3 frame_color = water_color;
	float3 final_color = frame_color * lambert + phong;
	return float4(final_color, 1);
};