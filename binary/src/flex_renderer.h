#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"
#include <vector>

#define MAX_PRIMATIVES 16384

class FlexRenderer {
private:
	std::vector<IMesh*> imeshes;
	void destroy_imeshes();

public:
	int get_total_imeshes();
	void build_imeshes(FlexSolver* solver, float radius);
	void draw_imeshes();

	FlexRenderer();
	~FlexRenderer();
};