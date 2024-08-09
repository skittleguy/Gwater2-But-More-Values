#pragma once

#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>
#include "ThreadPool.h"

#define MAX_PRIMATIVES 21845
#define SQRT3 1.73205081
#define VERTEX_GWATER2 VERTEX_POSITION | VERTEX_NORMAL | VERTEX_TEXCOORD0_2D

struct FlexRendererThreadData {
	VMatrix view_projection_matrix;
	Vector4D* particle_positions;
	Vector4D* particle_ani0;	// also used as triangle normals
	Vector4D* particle_ani1;
	Vector4D* particle_ani2;
	int* particle_phases;	// also used as triangle indices
	int* particle_active;
	Vector eye_pos;
	//int* render_buffer;
	int max_particles;
	float radius;
};

class FlexRenderer {
private:
	//int allocated = 0;
	ThreadPool* threads = nullptr;
	//int* water_buffer = nullptr;	// which particles should be rendered?
	//int* diffuse_buffer = nullptr;	// ^
	std::vector<std::future<IMesh*>> water_queue;
	std::vector<IMesh*> water_meshes;

	std::vector<std::future<IMesh*>> diffuse_queue;
	std::vector<IMesh*> diffuse_meshes;

	std::vector<std::future<IMesh*>> triangle_queue;
	std::vector<IMesh*> triangle_meshes;
	
	void destroy_meshes();
	void update_water();
	void update_diffuse();
	void update_cloth();
public:
	void draw_water();
	void draw_diffuse();
	void draw_cloth();

	void build_meshes(FlexSolver* flex, float diffuse_radius);

	FlexRenderer();
	~FlexRenderer();
};