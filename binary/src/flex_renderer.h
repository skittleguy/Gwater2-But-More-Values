#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>
#include <thread>
#include <mutex>
#include "ThreadPool.h"

#define MAX_PRIMATIVES 21845
#define MAX_THREADS 8
#define SQRT3 1.73205081

struct FlexRendererThreadData {
	//IMesh*& water;
	Vector eye_pos;
	VMatrix view_projection_matrix;
	Vector4D* particle_positions;
	Vector4D* particle_ani0;
	Vector4D* particle_ani1;
	Vector4D* particle_ani2;
	int* render_buffer;
	bool particle_ani;
	int max_particles;
	float radius;
};

class FlexRenderer {
private:
	//std::vector<IMesh*> diffuse;

public:
	int allocated = 0;
	ThreadPool* threads = nullptr;
	IMesh** water = nullptr;	// water meshes used in rendering
	int* render_buffer = nullptr;	// which particles should be rendered?
	std::future<IMesh*>* queue;

	void destroy_water();
	void update_water();
	void build_water(FlexSolver* flex, float radius);
	void build_diffuse(FlexSolver* flex, float radius);

	void draw_water();
	void draw_diffuse();

	FlexRenderer(int max_meshes);
	~FlexRenderer();
};