float radius 		: register(c0);

struct PS_INPUT {
	float2 P 			: VPOS;
	float2 world_coord	: TEXCOORD0;
	float3 world_dir	: TEXCOORD1;
	float3 world_normal	: TEXCOORD2;	// Broke?
	float3 world_color	: COLOR0;
	float3 world_depth 	: DEPTH0;
	float3 world_pos	: TEXCOORD3;
};

struct PS_OUTPUT {
	float4 rt0		    : COLOR0;
	float4 rt1          : COLOR1;
	float4 rt2			: COLOR2;
	float4 rt3			: COLOR3;
	//float depth			: DEPTH0;
};

PS_OUTPUT main(PS_INPUT i) {
	//return (float4(i.world_normal.x, i.world_normal.y, i.world_normal.z, 0) * 0.5) + float4(0.5, 0.5, 0.5, 1);
	
	float2 world_offset = (i.world_coord - 0.5) * 2.0;

	// kill pixels outside of sphere
	float radius2 = dot(world_offset, world_offset);
	if (radius2 > 1) discard;
	
	float3 right = normalize(cross(i.world_normal, float3(0, 0, 1)));
	float3 up = cross(i.world_normal, right);
	float bulge = sqrt(1 - radius2);
	float3 final_normal = -right * world_offset.x + up * world_offset.y + i.world_normal * bulge;

	float2 uvdx = ddx(i.world_coord);
	float2 uvdy = ddy(i.world_coord);
	float delta_max_sqr = max(dot(uvdx, uvdx), dot(uvdy, uvdy));

	float depth = length(i.world_dir);

	PS_OUTPUT o = (PS_OUTPUT)0;
	o.rt0 = float4(i.world_coord.x, i.world_coord.y, 0, 1);
	o.rt1 = float4(final_normal, 1);
	o.rt2 = float4(i.world_dir / depth, 1);
	o.rt3 = float4(sqrt(delta_max_sqr), depth / radius * 0.001, 0, 1);
	//float inverse = 1 / i.world_depth.y;
    //o.depth = (i.world_depth.x - (bulge * radius) * inverse) * inverse;
	return o;
};