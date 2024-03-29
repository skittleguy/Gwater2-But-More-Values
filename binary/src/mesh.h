#pragma once
#include <NvFlex.h>
#include "types.h"

// TODO: Rewrite this class as FlexMesh
// This class will handle all flex geometry related data. Think of it as a wrapper to flex collisions
// The idea is that these will be controlled completely by lua
// CONSTRUCTION AND DESTRUCTION OF THESE OBJECTS MUST NOT HAPPEN WITHIN THE FLEXSOLVER CLASS. THESE ARE COMPLETELY SEPARATE AND SHOULD BE HANDLED BY LUA!
// This class should be passed INTO the FlexSolver class as an argument into an array. If the memory becomes invalidated, it will simply be removed by the FlexSolver in pre_tick

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