
sampler NormalBuffer : register(s0);
sampler DepthBuffer	 : register(s1);
float2 size			 : register(c0);

struct PS_INPUT {
	float2 P 			: VPOS;
	float2 world_coord	: TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR {
	float4 depth = tex2D(DepthBuffer, i.world_coord); 
	if (depth.w != 1 || depth.y < 0.001) discard;

	float3 og_normal = tex2D(NormalBuffer, i.world_coord);
	float3 final_normal = og_normal;
	for (int x = -3; x <= 3; x++) {
		if (x == 0) continue;	// Skip center

		// Blend?
		float depth_mult = (1.0 / depth.x);
		float2 texcoord_pos = i.world_coord + float2(x * size.x, x * size.y) * depth_mult / SCR_S;		//((1 - depth.x) + 2 / depth.x) : 1)
		float4 neighbor_depth = tex2D(DepthBuffer, texcoord_pos);
		if (neighbor_depth.w != 1) continue;	// Sample isnt on a sphere
		if (abs(neighbor_depth.y - depth.y) > 0.001) continue;	// Sample is too far from other samples

		// Blend.
		float3 neighbor_normal = tex2D(NormalBuffer, texcoord_pos);
		final_normal += neighbor_normal;// * max(dot(og_normal, neighbor_normal), 0);
	}
	final_normal = normalize(final_normal);

	return float4(final_normal, 1);
};

/*
sampler NormalBuffer : register(s0);
sampler DepthBuffer     : register(s1);
float2 size             : register(c0);

struct PS_INPUT {
    float2 P             : VPOS;
    float2 world_coord    : TEXCOORD0;
};

float map(float s, float a1, float a2, float b1, float b2) {
    return b1 + (s-a1)*(b2-b1)/(a2-a1);
}

float4 main(PS_INPUT i) : COLOR {
    const float depthThreshold = 10;
    const float normalThreshold = 0.8; // the threshold 
    const bool shouldWeightByCosTheta = true; // weights with costheta
    const bool shouldWeightByDepthDifference = true;
    const float maxDepth = 0.6;

    float4 centerDepth = tex2D(DepthBuffer, i.world_coord); 
    if (centerDepth.y == 0) discard;
    //if (centerDepth.y > maxDepth) discard;

    float3 centerNormal = tex2D(NormalBuffer, i.world_coord);
    float3 finalNormal = centerNormal * 1;
    //finalNormal += float3(0, 0, 1);
    for (int x = -5; x <= 5; x++) {
        if (x == 0) continue; // skip center

        float2 texcoord_pos = i.world_coord + float2(x * size.x, x * size.y) * (1 / centerDepth.x) * (1 - clamp(centerDepth.y / maxDepth, 0, 1)) / SCR_S;
        float4 depth = tex2D(DepthBuffer, texcoord_pos);
        if (depth.y == 0) continue;

        float3 normal = tex2D(NormalBuffer, texcoord_pos);

        float cosTheta = dot(centerNormal, normal);
        float cosThetaClamped = max(0, map(cosTheta, normalThreshold, 1, 0, 1));

        float depthDifference = abs((centerDepth.x * 1000) - (depth.x * 1000));

        if (cosTheta > normalThreshold && depthDifference < depthThreshold) {
            float weight = (shouldWeightByCosTheta ? cosThetaClamped : 1);
            float depthWeight = (shouldWeightByDepthDifference ? 1 - (depthDifference / depthThreshold) : 1);
            finalNormal += normal * weight * depthWeight;
        }
    }

    finalNormal = normalize(finalNormal);
    return float4(finalNormal, 1);
};*/