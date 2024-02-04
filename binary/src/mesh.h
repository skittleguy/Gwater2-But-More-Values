#pragma once
#include <NvFlex.h>
#include "types.h"

class Mesh {
private:
	NvFlexLibrary* library = nullptr;
	NvFlexBuffer* vertices = nullptr;
	NvFlexBuffer* indices = nullptr;
	NvFlexTriangleMeshId id;

public:
	float4 pos = float4{};
	float4 ang = float4{};
	
	Mesh(NvFlexLibrary* lib);
	~Mesh();
	NvFlexTriangleMeshId get_id() { return this->id; }
	bool init_concave(float3* verts, int num_verts); // returns true on success, false otherwise
	bool init_convex(float3* verts, int num_verts);	// ^
	void update(float3 pos, float3 ang);
};