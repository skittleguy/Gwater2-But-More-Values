#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>
#include <thread>

#define MAX_PRIMATIVES 21845
#define SQRT3 1.73205081

enum ThreadStatus {
	MESH_NONE = 0,
	MESH_EXISTS = 1,
	MESH_BUILDING = 2,
};

struct FlexRendererThreadData {
	IMatRenderContext* render_context;
	Vector eye_pos;
	VMatrix view_projection_matrix;
	Vector4D* particle_positions;
	//Vector4D* particle_ani0;
	//Vector4D* particle_ani1;
	//Vector4D* particle_ani2;
	//bool particle_ani;
	int max_particles;
	float radius;
	int id;
};

class FlexRenderer {
private:
	//std::vector<IMesh*> diffuse;

public:
	int allocated = 0;
	IMesh** water;	// water meshes used in rendering
	ThreadStatus* thread_status;	// status of threads
	FlexRendererThreadData* thread_data;	// data passed to threads

	void build_water(float radius);
	void build_diffuse(float radius);

	void draw_water();
	void draw_diffuse();

	FlexRenderer(int max_meshes);
	~FlexRenderer();
};