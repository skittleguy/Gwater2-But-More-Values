#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>
#include <thread>
#include <mutex>

#define MAX_PRIMATIVES 21845
#define SQRT3 1.73205081

enum ThreadStatus {
	MESH_NONE = -2,
	MESH_NONE_BUILDING = -1,
	MESH_KILL = 0,	// tell thread to kill itself
	MESH_EXISTS = 1,
	MESH_EXISTS_BUILDING = 2,
};

struct FlexRendererThreadData {
	IMesh*& water;
	ThreadStatus& thread_status;
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
};

class FlexRenderer {
private:
	//std::vector<IMesh*> diffuse;

public:
	int allocated = 0;
	IMesh** water = nullptr;	// water meshes used in rendering
	std::thread* threads = nullptr;	// actual thread objects
	ThreadStatus* thread_status = nullptr;	// status of threads
	FlexRendererThreadData* thread_data = nullptr;	// data passed to threads

	void build_water(FlexSolver* flex, float radius);
	void build_diffuse(FlexSolver* flex, float radius);

	void draw_water();
	void draw_diffuse();

	FlexRenderer(int max_meshes);
	~FlexRenderer();
};