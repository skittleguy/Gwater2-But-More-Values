#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>

#define MAX_PRIMATIVES 21845
#define SQRT3 1.73205081

class FlexRenderer {
private:
	std::vector<IMesh*> water;
	std::vector<IMesh*> diffuse;

public:
	void build_water(FlexSolver* solver, float radius);
	void build_diffuse(FlexSolver* solver, float radius);

	void draw_water();
	void draw_diffuse();

	FlexRenderer();
	~FlexRenderer();
};