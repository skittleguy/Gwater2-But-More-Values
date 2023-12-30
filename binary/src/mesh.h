#pragma once
#include <NvFlex.h>
#include "types.h"

struct Mesh {
private:
	NvFlexLibrary* library = nullptr;
	NvFlexBuffer* vertices = nullptr;
	NvFlexBuffer* indices = nullptr;
	NvFlexTriangleMeshId id;

public:
	float4 pos = float4{};
	float4 ang = float4{};
	
	Mesh(NvFlexLibrary* lib);
	// Returns the FleX internal ID associated with the mesh
	NvFlexTriangleMeshId get_id() { return this->id; }

	bool init_concave(float3* verts, int num_verts); // Initializes mesh with concave data. True on success, false otherwise
	bool init_convex(float3* verts, int num_verts);	// Initializes mesh with convex data. True on success, false otherwise
	void update(float3 pos, float3 ang);
	void destroy();
};