#include "mesh.h"

#define _PI 3.14159265358979323846f
float rad(float degree) {
	return (degree * (_PI / 180));
}

// provided by PotatoOS
Vector4D unfuckQuat(Vector4D q) {
	return Vector4D(q.y, q.z, q.w, q.x);
}

// Angle to Quat conversion provided by Wikipidia (https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles)
Vector4D angle_to_quat(QAngle ang) {
	float p = rad(ang.x) / 2.0;
	float y = rad(ang.y) / 2.0;
	float r = rad(ang.z) / 2.0;
	float cr = cos(r);
	float sr = sin(r);
	float cp = cos(p);
	float sp = sin(p);
	float cy = cos(y);
	float sy = sin(y);

	return unfuckQuat(Vector4D(
		cr * cp * cy + sr * sp * sy,
		sr * cp * cy - cr * sp * sy,
		cr * sp * cy + sr * cp * sy,
		cr * cp * sy - sr * sp * cy
	));
}

Mesh::Mesh(NvFlexLibrary* lib) {
	this->library = lib; 
}

Mesh::~Mesh() {
	NvFlexFreeBuffer(vertices);
	if (indices == nullptr) {
		NvFlexDestroyConvexMesh(library, id);
	}
	else {	// Convex meshes dont have an indices buffer, so the mesh must be concave
		NvFlexFreeBuffer(indices);
		NvFlexDestroyTriangleMesh(library, id);
	}
}

bool Mesh::init_concave(Vector* verts, int num_verts) {
	if (num_verts == 0 || num_verts % 3 != 0) {
		return false;
	}

	// Allocate buffers
	this->vertices = NvFlexAllocBuffer(library, num_verts, sizeof(Vector4D), eNvFlexBufferHost);
	this->indices = NvFlexAllocBuffer(library, num_verts, sizeof(int), eNvFlexBufferHost);

	Vector4D* hostVerts = (Vector4D*)NvFlexMap(this->vertices, eNvFlexMapWait);
	int* hostIndices = (int*)NvFlexMap(this->indices, eNvFlexMapWait);

	float min[3] = { verts[0].x, verts[0].y, verts[0].z };
	float max[3] = { verts[0].x, verts[0].y, verts[0].z };
	for (int i = 0; i < num_verts; i++) {
		hostVerts[i] = Vector4D(verts[i].x, verts[i].y, verts[i].z, 0);
		hostIndices[i] = i + (i % 3 < 2 ? (i % 3 == 0 ? 1 : -1) : 0);    // flip triangle winding

		min[0] = fmin(min[0], verts[i].x); 
		min[1] = fmin(min[1], verts[i].y);
		min[2] = fmin(min[2], verts[i].z);

		max[0] = fmax(max[0], verts[i].x);
		max[1] = fmax(max[1], verts[i].y);
		max[2] = fmax(max[2], verts[i].z);
	}
	NvFlexUnmap(this->vertices);
	NvFlexUnmap(this->indices);

	this->id = NvFlexCreateTriangleMesh(library);

	NvFlexUpdateTriangleMesh(this->library, this->id, this->vertices, this->indices, num_verts, num_verts / 3, min, max);

	return true;
}

bool Mesh::init_convex(Vector* verts, int num_verts) {
	if (num_verts == 0 || num_verts % 3 != 0) {
		return false;
	}

	// Allocate buffers
	this->vertices = NvFlexAllocBuffer(this->library, num_verts / 3, sizeof(Vector4D), eNvFlexBufferHost);
	Vector4D* hostVerts = (Vector4D*)NvFlexMap(this->vertices, eNvFlexMapWait);

	float min[3] = { verts[0].x, verts[0].y, verts[0].z };
	float max[3] = { verts[0].x, verts[0].y, verts[0].z };
	for (int i = 0; i < num_verts; i += 3) {
		Vector tri[3] = {verts[i], verts[i + 1], verts[i + 2]};

		// Turn triangle into normalized plane & add to vertex buffer
		Vector plane_dir = (tri[1] - tri[0]).Cross(tri[0] - tri[2]).Normalized();
		float plane_height = plane_dir.Dot(tri[0]);
		hostVerts[i / 3] = Vector4D(plane_dir.x, plane_dir.y, plane_dir.z, -plane_height);

		min[0] = fmin(min[0], verts[i].x);
		min[1] = fmin(min[1], verts[i].y);
		min[2] = fmin(min[2], verts[i].z);

		max[0] = fmax(max[0], verts[i].x);
		max[1] = fmax(max[1], verts[i].y);
		max[2] = fmax(max[2], verts[i].z);
	}
	NvFlexUnmap(this->vertices);

	this->id = NvFlexCreateConvexMesh(library);
	NvFlexUpdateConvexMesh(this->library, this->id, this->vertices, num_verts / 3, min, max);

	return true;
}

void Mesh::update(Vector pos, QAngle ang) {
	this->pos = Vector4D(pos.x, pos.y, pos.z, 0);	// unsure what the last number is for. FleX requires it to exist
	this->ang = angle_to_quat(ang);
}