#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>
#include <thread>

#define MAX_PRIMATIVES 21845
#define SQRT3 1.73205081

class FlexRenderer {
private:
	FlexSolver* flex = nullptr;
	IMesh** water = nullptr;	// water meshes used in rendering
	int water_max = 0;
	//std::vector<IMesh*> diffuse;

public:
	IMesh** get_water();

	void build_mesh(FlexSolver* flex, float radius, int thread_id);
	void build_water(float radius);
	void build_diffuse(float radius);

	void draw_water();
	void draw_diffuse();

	FlexRenderer(FlexSolver* flex);
	~FlexRenderer();
};