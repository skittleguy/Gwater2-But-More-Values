#pragma once
#include <NvFlex.h>
#include "mathlib/vector.h"
#include "mathlib/vector4d.h"
#include <vector>

// Handles colliders in FleX
class FlexMesh {
private:
	int mesh_id;	// id associated with the entity its attached to in source, as some physmeshes have multiple colliders (eg. ragdolls)
	NvFlexTriangleMeshId id;
	int flags;
	NvFlexBuffer* vertices = nullptr;
	NvFlexBuffer* indices = nullptr;

	Vector4D pos = Vector4D(0, 0, 0, 0);
	Vector4D ang = Vector4D(0, 0, 0, 1); // Quaternion

	Vector4D ppos = Vector4D(0, 0, 0, 0);	// Previous pos
	Vector4D pang = Vector4D(0, 0, 0, 1);	// Previous ang

public:
	FlexMesh(int mesh_id);

	bool init_concave(NvFlexLibrary* lib, std::vector<Vector> verts, bool dynamic);	
	bool init_concave(NvFlexLibrary* lib, Vector* verts, int num_verts, bool dynamic);	
	bool init_convex(NvFlexLibrary* lib, std::vector<Vector> verts, bool dynamic);
	void destroy(NvFlexLibrary* lib);

	void set_pos(Vector pos);
	void set_ang(QAngle ang);

	Vector4D get_pos();	// Returns a Vector4D for convenience
	Vector4D get_ang();

	Vector4D get_ppos();
	Vector4D get_pang();

	NvFlexTriangleMeshId get_id();
	int get_mesh_id();
	int get_flags();

	void update();
};