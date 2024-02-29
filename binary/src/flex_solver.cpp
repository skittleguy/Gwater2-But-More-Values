#pragma once
#include "flex_solver.h"

#define MAX_COLLIDERS 8192	// source can't go over this number of props so.. might as well just have it as the limit

//extern IMaterialSystem* materials = NULL;	// stops main branch compile from bitching

// todo: add smartcomments

// Struct that holds FleX solver data
void FlexSolver::add_buffer(std::string name, int type, int count) {
	NvFlexBuffer* buffer = NvFlexAllocBuffer(library, count, type, eNvFlexBufferHost);
	buffers[name] = buffer;
};

inline NvFlexBuffer* FlexSolver::get_buffer(std::string name) {
	return buffers[name];
}

void FlexSolver::set_active_particles(int n) {
	copy_description->elementCount = n;
}

int FlexSolver::get_active_particles() {
	return copy_description->elementCount;
}

int FlexSolver::get_max_particles() {
	return solver_description.maxParticles;
}

int FlexSolver::get_max_contacts() {
	return solver_description.maxContactsPerParticle;
}

float4* FlexSolver::get_host(std::string name) {
	return hosts[name];
}

void FlexSolver::add_particle(float4 pos, float3 vel) {
	if (solver == nullptr) return;

	if (get_active_particles() >= get_max_particles()) return;

	// map buffers for reading / writing
	hosts["particle_smooth"] = (float4*)NvFlexMap(get_buffer("particle_smooth"), eNvFlexMapWait);
	hosts["particle_pos"] = (float4*)NvFlexMap(get_buffer("particle_pos"), eNvFlexMapWait);
	float3* velocities = (float3*)NvFlexMap(get_buffer("particle_vel"), eNvFlexMapWait);
	int* phases = (int*)NvFlexMap(get_buffer("particle_phase"), eNvFlexMapWait);
	int* active = (int*)NvFlexMap(get_buffer("particle_active"), eNvFlexMapWait);

	// Add particle
	int n = copy_description->elementCount++;	// increment
	hosts["particle_pos"][n] = pos;
	hosts["particle_smooth"][n] = pos;
	velocities[n] = vel;
	phases[n] = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid);
	active[n] = n;

	// unmap buffers
	NvFlexUnmap(get_buffer("particle_smooth"));
	NvFlexUnmap(get_buffer("particle_pos"));
	NvFlexUnmap(get_buffer("particle_vel"));
	NvFlexUnmap(get_buffer("particle_phase"));
	NvFlexUnmap(get_buffer("particle_active"));
}


// Handles transfer of FleX buffers to hosts & updates mesh positions/angles
bool FlexSolver::pretick(NvFlexMapFlags wait) {
	if (solver == nullptr) return false;

	// Copy position memory
	float4* positions = (float4*)NvFlexMap(get_buffer("particle_pos"), wait);
	if (!positions) return false;
	hosts["particle_pos"] = positions;
	NvFlexUnmap(get_buffer("particle_pos"));

	// Copy anisotropy & smoothing (used in rendering)
	hosts["particle_ani1"] = (float4*)NvFlexMap(get_buffer("particle_ani1"), eNvFlexMapWait);
	hosts["particle_ani2"] = (float4*)NvFlexMap(get_buffer("particle_ani2"), eNvFlexMapWait);
	hosts["particle_ani3"] = (float4*)NvFlexMap(get_buffer("particle_ani3"), eNvFlexMapWait);
	hosts["particle_smooth"] = (float4*)NvFlexMap(get_buffer("particle_smooth"), eNvFlexMapWait);
	NvFlexUnmap(get_buffer("particle_ani1"));
	NvFlexUnmap(get_buffer("particle_ani2"));
	NvFlexUnmap(get_buffer("particle_ani3"));
	NvFlexUnmap(get_buffer("particle_smooth"));

	// Update collider positions
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	for (int i = 0; i < meshes.size(); i++) {
		Mesh* mesh = meshes[i];
		ppos[i] = pos[i];
		pos[i] = mesh->pos;

		pang[i] = ang[i];
		ang[i] = mesh->ang;
	}
	NvFlexUnmap(get_buffer("geometry_pos"));
	NvFlexUnmap(get_buffer("geometry_prevpos"));
	NvFlexUnmap(get_buffer("geometry_quat"));
	NvFlexUnmap(get_buffer("geometry_prevquat"));

	return true;
}

// ticks the solver
void FlexSolver::tick(float dt) {
	if (solver == nullptr) return;
	// write to device (async)
	NvFlexSetParticles(solver, get_buffer("particle_pos"), copy_description);
	NvFlexSetVelocities(solver, get_buffer("particle_vel"), copy_description);
	NvFlexSetPhases(solver, get_buffer("particle_phase"), copy_description);
	NvFlexSetActive(solver, get_buffer("particle_active"), copy_description);
	NvFlexSetActiveCount(solver, copy_description->elementCount);
	NvFlexSetParams(solver, params);
	NvFlexSetShapes(solver,
		get_buffer("geometry"),
		get_buffer("geometry_pos"),
		get_buffer("geometry_quat"),
		get_buffer("geometry_prevpos"),
		get_buffer("geometry_prevquat"),
		get_buffer("geometry_flags"),
		meshes.size()
	);

	// tick
	NvFlexUpdateSolver(solver, dt * (*param_map["timescale"]), (int)(*param_map["substeps"]), false);

	// read back (async)
	NvFlexGetParticles(solver, get_buffer("particle_pos"), copy_description);
	NvFlexGetVelocities(solver, get_buffer("particle_vel"), copy_description);
	NvFlexGetPhases(solver, get_buffer("particle_phase"), copy_description);
	NvFlexGetActive(solver, get_buffer("particle_active"), copy_description);
	//NvFlexGetContacts(solver, get_buffer("contact_planes"), get_buffer("contact_vel"), get_buffer("contact_indices"), get_buffer("contact_count"));
	if (get_parameter("anisotropy_scale") != 0) NvFlexGetAnisotropy(solver, get_buffer("particle_ani1"), get_buffer("particle_ani2"), get_buffer("particle_ani3"), copy_description);
	if (get_parameter("smoothing") != 0) NvFlexGetSmoothParticles(solver, get_buffer("particle_smooth"), copy_description);
}

void FlexSolver::add_mesh(Mesh* mesh, NvFlexCollisionShapeType mesh_type, bool dynamic) {
	if (solver == nullptr) return;

	int index = meshes.size();
	meshes.push_back(mesh);

	NvFlexCollisionGeometry* geo = (NvFlexCollisionGeometry*)NvFlexMap(get_buffer("geometry"), eNvFlexMapWait);
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	int* flag = (int*)NvFlexMap(get_buffer("geometry_flags"), eNvFlexMapWait);

	flag[index] = NvFlexMakeShapeFlags(mesh_type, dynamic);
	geo[index].triMesh.mesh = mesh->get_id();
	geo[index].triMesh.scale[0] = 1;
	geo[index].triMesh.scale[1] = 1;
	geo[index].triMesh.scale[2] = 1;

	geo[index].convexMesh.mesh = mesh->get_id();
	geo[index].convexMesh.scale[0] = 1;
	geo[index].convexMesh.scale[1] = 1;
	geo[index].convexMesh.scale[2] = 1;

	pos[index] = mesh->pos;
	ppos[index] = mesh->pos;
	ang[index] = mesh->ang;
	pang[index] = mesh->ang;

	NvFlexUnmap(get_buffer("geometry"));
	NvFlexUnmap(get_buffer("geometry_pos"));
	NvFlexUnmap(get_buffer("geometry_prevpos"));
	NvFlexUnmap(get_buffer("geometry_quat"));
	NvFlexUnmap(get_buffer("geometry_prevquat"));
	NvFlexUnmap(get_buffer("geometry_flags"));
}

void FlexSolver::remove_mesh(int index) {
	if (solver == nullptr) return;

	// Free mesh buffers
	delete meshes[index];

	NvFlexCollisionGeometry* geo = (NvFlexCollisionGeometry*)NvFlexMap(get_buffer("geometry"), eNvFlexMapWait);
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	int* flag = (int*)NvFlexMap(get_buffer("geometry_flags"), eNvFlexMapWait);

	// "Remove" prop by shifting everything down onto it
	for (int i = index; i < meshes.size() - 1; i++) {
		int i2 = i + 1;
		geo[i] = geo[i2];
		pos[i] = pos[i2];
		ppos[i] = ppos[i2];
		ang[i] = ang[i2];
		pang[i] = pang[i2];
		flag[i] = flag[i2];
		meshes[i] = meshes[i2];
	}
	meshes.pop_back();

	NvFlexUnmap(get_buffer("geometry"));
	NvFlexUnmap(get_buffer("geometry_pos"));
	NvFlexUnmap(get_buffer("geometry_prevpos"));
	NvFlexUnmap(get_buffer("geometry_quat"));
	NvFlexUnmap(get_buffer("geometry_prevquat"));
	NvFlexUnmap(get_buffer("geometry_flags"));
}

// sets the position and angles of a mesh object. The inputted angle is Eular
void FlexSolver::update_mesh(int index, float3 new_pos, float3 new_ang) {
	if (solver == nullptr) return;
	
	meshes[index]->update(new_pos, new_ang);
}

bool FlexSolver::set_parameter(std::string param, float number) {
	try {
		*param_map.at(param) = number;
		return true;
	}
	catch (std::exception e) {
		if (param == "iterations") {	// defined as an int instead of a float, so it needs to be seperate
			params->numIterations = (int)number;
			return true;
		}
		return false;
	}
}

// Returns NaN on failure
float FlexSolver::get_parameter(std::string param) {
	try {
		return *param_map.at(param);
	}
	catch (std::exception e) {
		if (param == "iterations") {	// ^
			return (float)params->numIterations;
		}
		return NAN;
	}
}

// Initializes a box around a FleX solver with a mins and maxs
void FlexSolver::enable_bounds(float3 mins, float3 maxs) {

	// Right
	params->planes[0][0] = 1.f;
	params->planes[0][1] = 0.f;
	params->planes[0][2] = 0.f;
	params->planes[0][3] = -mins.x;

	// Left
	params->planes[1][0] = -1.f;
	params->planes[1][1] = 0.f;
	params->planes[1][2] = 0.f;
	params->planes[1][3] = maxs.x;

	// Forward
	params->planes[2][0] = 0.f;
	params->planes[2][1] = 1.f;
	params->planes[2][2] = 0.f;
	params->planes[2][3] = -mins.y;

	// Backward
	params->planes[3][0] = 0.f;
	params->planes[3][1] = -1.f;
	params->planes[3][2] = 0.f;
	params->planes[3][3] = maxs.y;

	// Bottom
	params->planes[4][0] = 0.f;
	params->planes[4][1] = 0.f;
	params->planes[4][2] = 1.f;
	params->planes[4][3] = -mins.z;

	// Top
	params->planes[5][0] = 0.f;
	params->planes[5][1] = 0.f;
	params->planes[5][2] = -1.f;
	params->planes[5][3] = maxs.z;

	params->numPlanes = 6;
}

void FlexSolver::disable_bounds() {
	params->numPlanes = 0;
}

// Initializes a solver in a FleX library
FlexSolver::FlexSolver(NvFlexLibrary* library, int particles) {
	if (library == nullptr) return;		// Panic

	NvFlexSetSolverDescDefaults(&solver_description);
	solver_description.maxParticles = particles;
	solver_description.maxDiffuseParticles = 0;

	library = library;
	solver = NvFlexCreateSolver(library, &solver_description);

	default_parameters();
	map_parameters(params);

	add_buffer("particle_pos", sizeof(float4), particles);
	add_buffer("particle_vel", sizeof(float3), particles);
	add_buffer("particle_phase", sizeof(int), particles);
	add_buffer("particle_active", sizeof(int), particles);
	add_buffer("particle_smooth", sizeof(float4), particles);

	add_buffer("geometry", sizeof(NvFlexCollisionGeometry), MAX_COLLIDERS);
	add_buffer("geometry_pos", sizeof(float4), MAX_COLLIDERS);
	add_buffer("geometry_prevpos", sizeof(float4), MAX_COLLIDERS);
	add_buffer("geometry_quat", sizeof(float4), MAX_COLLIDERS);
	add_buffer("geometry_prevquat", sizeof(float4), MAX_COLLIDERS);
	add_buffer("geometry_flags", sizeof(int), MAX_COLLIDERS);

	add_buffer("contact_planes", sizeof(float4), particles * get_max_contacts());
	add_buffer("contact_vel", sizeof(float4), particles * get_max_contacts());
	add_buffer("contact_count", sizeof(int), particles);
	add_buffer("contact_indices", sizeof(int), particles);

	add_buffer("particle_ani1", sizeof(float4), particles);
	add_buffer("particle_ani2", sizeof(float4), particles);
	add_buffer("particle_ani3", sizeof(float4), particles);
};

// Free memory
FlexSolver::~FlexSolver() {
	if (solver == nullptr) return;

	// Free props
	for (Mesh* mesh : meshes) 
		delete mesh;
	meshes.clear();

	delete param_map["substeps"];		// Seperate since its externally stored & not a default parameter
	delete param_map["timescale"];		// ^

	// Free flex buffers
	for (std::pair<std::string, NvFlexBuffer*> buffer : buffers) 
		NvFlexFreeBuffer(buffer.second);

	NvFlexDestroySolver(solver);	// bye bye solver
	solver = nullptr;
}

void FlexSolver::default_parameters() {
	params = new NvFlexParams();
	params->gravity[0] = 0.0f;
	params->gravity[1] = 0.0f;
	params->gravity[2] = -15.24f;	// Source gravity (600 inch^2) in m/s^2

	params->wind[0] = 0.0f;
	params->wind[1] = 0.0f;
	params->wind[2] = 0.0f;

	params->radius = 10.f;
	params->viscosity = 0.0f;
	params->dynamicFriction = 0.5f;
	params->staticFriction = 0.5f;
	params->particleFriction = 0.0f;
	params->freeSurfaceDrag = 0.0f;
	params->drag = 0.0f;
	params->lift = 1.0f;
	params->numIterations = 3;
	params->fluidRestDistance = 7.f;
	params->solidRestDistance = 7.f;

	params->anisotropyScale = 1.f;
	params->anisotropyMin = 0.0f;
	params->anisotropyMax = 0.15f;
	params->smoothing = 1.0f;

	params->dissipation = 0.f;
	params->damping = 0.0f;
	params->particleCollisionMargin = 0.f;
	params->shapeCollisionMargin = 0.f;	// Increase if lots of water pressure is expected. Higher values cause more collision clipping
	params->collisionDistance = 5.f; // Needed for tri-particle intersection
	params->sleepThreshold = 0.1f;
	params->shockPropagation = 0.0f;
	params->restitution = 0.0f;

	params->maxSpeed = 1e10;
	params->maxAcceleration = 200.0f;
	params->relaxationMode = eNvFlexRelaxationLocal;
	params->relaxationFactor = 0.0f;
	params->solidPressure = 0.5f;
	params->adhesion = 0.0f;
	params->cohesion = 0.005f;
	params->surfaceTension = 0.000001f;
	params->vorticityConfinement = 0.0f;
	params->buoyancy = 1.0f;

	params->diffuseThreshold = 3.f;
	params->diffuseBuoyancy = 1.f;
	params->diffuseDrag = 0.8f;
	params->diffuseBallistic = 0;
	params->diffuseLifetime = 30.0f;

	params->numPlanes = 0;
};

void FlexSolver::map_parameters(NvFlexParams* buffer) {
	param_map["gravity"] = &(buffer->gravity[2]);
	param_map["radius"] = &buffer->radius;
	param_map["viscosity"] = &buffer->viscosity;
	param_map["dynamic_friction"] = &buffer->dynamicFriction;
	param_map["static_friction"] = &buffer->staticFriction;
	param_map["particle_friction"] = &buffer->particleFriction;
	param_map["free_surface_drag"] = &buffer->freeSurfaceDrag;
	param_map["drag"] = &buffer->drag;
	param_map["lift"] = &buffer->lift;
	//param_map["num_iterations"] = &buffer->numIterations;		// integer, cant map
	param_map["fluid_rest_distance"] = &buffer->fluidRestDistance;
	param_map["solid_rest_distance"] = &buffer->solidRestDistance;
	param_map["anisotropy_scale"] = &buffer->anisotropyScale;
	param_map["anisotropy_min"] = &buffer->anisotropyMin;
	param_map["anisotropy_max"] = &buffer->anisotropyMax;
	param_map["dissipation"] = &buffer->dissipation;
	param_map["damping"] = &buffer->damping;
	param_map["particle_collision_margin"] = &buffer->particleCollisionMargin;
	param_map["shape_collision_margin"] = &buffer->shapeCollisionMargin;
	param_map["collision_distance"] = &buffer->collisionDistance;
	param_map["sleep_threshold"] = &buffer->sleepThreshold;
	param_map["shock_propagation"] = &buffer->shockPropagation;
	param_map["restitution"] = &buffer->restitution;
	param_map["max_speed"] = &buffer->maxSpeed;
	param_map["max_acceleration"] = &buffer->maxAcceleration;	
	//param_map["relaxation_mode"] = &buffer->relaxationMode;		// ^
	param_map["relaxation_factor"] = &buffer->relaxationFactor;
	param_map["solid_pressure"] = &buffer->solidPressure;
	param_map["adhesion"] = &buffer->adhesion;
	param_map["cohesion"] = &buffer->cohesion;
	param_map["surface_tension"] = &buffer->surfaceTension;
	param_map["vorticity_confinement"] = &buffer->vorticityConfinement;
	param_map["buoyancy"] = &buffer->buoyancy;
	param_map["smoothing"] = &buffer->smoothing;

	// Extra values we store which are not stored in flexes default parameters
	param_map["substeps"] = new float(3);
	param_map["timescale"] = new float(1);
}