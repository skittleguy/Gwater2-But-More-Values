#include "mesh.h"

// Angle to Quat conversion provided by Wikipidia (https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles)

#define _PI 3.14159265358979323846f
float rad(float degree) {
	return (degree * (_PI / 180));
}

float4 unfuckQuat(float4 q) {
	return float4(q.y, q.z, q.w, q.x);
}

float4 quatFromAngle(float3 ang) {
	float p = rad(ang.x) / 2.0;
	float y = rad(ang.y) / 2.0;
	float r = rad(ang.z) / 2.0;
	float cr = cos(r);
	float sr = sin(r);
	float cp = cos(p);
	float sp = sin(p);
	float cy = cos(y);
	float sy = sin(y);

	return unfuckQuat(float4(
		cr * cp * cy + sr * sp * sy,
		sr * cp * cy - cr * sp * sy,
		cr * sp * cy + sr * cp * sy,
		cr * cp * sy - sr * sp * cy
	));
}

Mesh::Mesh(NvFlexLibrary* lib) {
	this->library = lib; 
	update(float3(), float3());
}

void Mesh::init_obb(float3 min, float3 max) {
	this->min = new float[3] { min.x, min.y, min.z };
	this->max = new float[3] { max.x, max.y, max.z };
}

bool Mesh::init_concave(float3* verts, int num_verts) {
	if (num_verts == 0 || num_verts % 3 != 0) {
		return false;
	}

	// Allocate buffers
	this->vertices = NvFlexAllocBuffer(library, num_verts, sizeof(float4), eNvFlexBufferHost);
	this->indices = NvFlexAllocBuffer(library, num_verts, sizeof(int), eNvFlexBufferHost);

	float4* hostVerts = (float4*)NvFlexMap(this->vertices, eNvFlexMapWait);
	int* hostIndices = (int*)NvFlexMap(this->indices, eNvFlexMapWait);

	for (int i = 0; i < num_verts; i++) {
		hostVerts[i] = float4(verts[i].x, verts[i].y, verts[i].z, 0);
		hostIndices[i] = i + (i % 3 < 2 ? (i % 3 == 0 ? 1 : -1) : 0);    // flip triangle winding
	}
	NvFlexUnmap(this->vertices);
	NvFlexUnmap(this->indices);

	this->id = NvFlexCreateTriangleMesh(library);
	NvFlexUpdateTriangleMesh(this->library, this->id, this->vertices, this->indices, num_verts, num_verts / 3, this->min, this->max);

	return true;
}

bool Mesh::init_convex(float3* verts, int num_verts) {
	if (num_verts == 0 || num_verts % 3 != 0) {
		return false;
	}

	// Allocate buffers
	this->vertices = NvFlexAllocBuffer(this->library, num_verts / 3, sizeof(float4), eNvFlexBufferHost);
	float4* hostVerts = (float4*)NvFlexMap(this->vertices, eNvFlexMapWait);
	for (int i = 0; i < num_verts; i += 3) {
		float3 tri[3] = {verts[i], verts[i + 1], verts[i + 2]};

		// Turn triangle into normalized plane & add to vertex buffer
		float3 plane_dir = Normalize(Cross(tri[1] - tri[0], tri[0] - tri[2]));
		float plane_height = Dot(plane_dir, tri[0]);
		hostVerts[i / 3] = float4(plane_dir.x, plane_dir.y, plane_dir.z, -plane_height);
	}
	NvFlexUnmap(this->vertices);

	this->id = NvFlexCreateConvexMesh(library);
	NvFlexUpdateConvexMesh(this->library, this->id, this->vertices, num_verts / 3, this->min, this->max);

	return true;
}

void Mesh::update(float3 pos, float3 ang) {
	this->pos = float4(pos.x, pos.y, pos.z, 0);	// unsure what the last number is for. FleX requires it to exist
	this->ang = quatFromAngle(ang);
}

void Mesh::destroy() {
	NvFlexFreeBuffer(vertices);
	if (indices == nullptr) {
		NvFlexDestroyConvexMesh(library, id);
	}
	else {	// Convex meshes dont have an indices buffer, so the mesh must be concave
		NvFlexFreeBuffer(indices);
		NvFlexDestroyTriangleMesh(library, id);
	}

	delete this->min;
	delete this->max;
}