#pragma once
#include <materialsystem/imesh.h>
#include <istudiorender.h>
#include "meshutils.h"		// Fixes linker errors
#include "flex_solver.h"

#define MAX_INDICES 65536

class FlexRenderer {
private:
	FlexSolver* solver;
	IMesh** imeshes;
	int num_imeshes = 0;

public:
	int get_total_imeshes();
	void build_imeshes(float radius);
	void render_imeshes();

	FlexRenderer(FlexSolver* s);
	~FlexRenderer();
};