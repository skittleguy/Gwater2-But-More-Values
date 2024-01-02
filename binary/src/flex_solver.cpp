#pragma once
#include "flex_solver.h"

#define MAX_COLLIDERS 8192	// source can't go over this number of props so.. might as well just have it as the limit

//FIXME: ADD SMARTCOMMENTS

// Struct that holds FleX solver data
void FlexSolver::add_buffer(std::string name, int type, int count) {
	NvFlexBuffer* buffer = NvFlexAllocBuffer(this->library, count, type, eNvFlexBufferHost);
	this->buffers[name] = buffer;
};

NvFlexBuffer* FlexSolver::get_buffer(std::string name) {
	return this->buffers[name];
}

void FlexSolver::set_active_particles(int n) {
	this->copy_description->elementCount = n;
}

int FlexSolver::get_active_particles() {
	return this->copy_description->elementCount;
}

int FlexSolver::get_max_particles() {
	return this->solver_description.maxParticles;
}

int FlexSolver::get_max_contacts() {
	return this->solver_description.maxContactsPerParticle;
}

float4* FlexSolver::get_host(std::string name) {
	return this->hosts[name];
}

void FlexSolver::add_particle(float4 pos, float3 vel, float4 col) {
	if (this->solver == nullptr) return;

	if (get_active_particles() >= get_max_particles()) return;

	// map buffers for reading / writing
	this->hosts["particle_smooth"] = (float4*)NvFlexMap(get_buffer("particle_smooth"), eNvFlexMapWait);
	this->hosts["particle_pos"] = (float4*)NvFlexMap(get_buffer("particle_pos"), eNvFlexMapWait);
	float3* velocities = (float3*)NvFlexMap(get_buffer("particle_vel"), eNvFlexMapWait);
	int* phases = (int*)NvFlexMap(get_buffer("particle_phase"), eNvFlexMapWait);
	int* active = (int*)NvFlexMap(get_buffer("particle_active"), eNvFlexMapWait);

	// Add particle
	int n = this->copy_description->elementCount++;	// increment
	this->hosts["particle_pos"][n] = pos;
	this->hosts["particle_smooth"][n] = pos;
	this->hosts["particle_col"][n] = col;
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
	if (this->solver == nullptr) return false;

	// Copy position memory
	float4* positions = (float4*)NvFlexMap(get_buffer("particle_pos"), wait);
	if (!positions) return false;
	this->hosts["particle_pos"] = positions;
	NvFlexUnmap(get_buffer("particle_pos"));

	// Copy anisotropy & smoothing (used in rendering)
	this->hosts["particle_ani1"] = (float4*)NvFlexMap(get_buffer("particle_ani1"), eNvFlexMapWait);
	this->hosts["particle_ani2"] = (float4*)NvFlexMap(get_buffer("particle_ani2"), eNvFlexMapWait);
	this->hosts["particle_ani3"] = (float4*)NvFlexMap(get_buffer("particle_ani3"), eNvFlexMapWait);
	this->hosts["particle_smooth"] = (float4*)NvFlexMap(get_buffer("particle_smooth"), eNvFlexMapWait);
	NvFlexUnmap(get_buffer("particle_ani1"));
	NvFlexUnmap(get_buffer("particle_ani2"));
	NvFlexUnmap(get_buffer("particle_ani3"));
	NvFlexUnmap(get_buffer("particle_smooth"));

	// Update collider positions
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	for (int i = 0; i < this->meshes.size(); i++) {
		Mesh* mesh = &this->meshes[i];
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
	if (this->solver == nullptr) return;
	// write to device (async)
	NvFlexSetParticles(this->solver, get_buffer("particle_pos"), this->copy_description);
	NvFlexSetVelocities(this->solver, get_buffer("particle_vel"), this->copy_description);
	NvFlexSetPhases(this->solver, get_buffer("particle_phase"), this->copy_description);
	NvFlexSetActive(this->solver, get_buffer("particle_active"), this->copy_description);
	NvFlexSetActiveCount(this->solver, this->copy_description->elementCount);
	NvFlexSetParams(this->solver, this->params);
	NvFlexSetShapes(this->solver,
		get_buffer("geometry"),
		get_buffer("geometry_pos"),
		get_buffer("geometry_quat"),
		get_buffer("geometry_prevpos"),
		get_buffer("geometry_prevquat"),
		get_buffer("geometry_flags"),
		this->meshes.size()
	);

	// tick
	NvFlexUpdateSolver(this->solver, dt * (*this->param_map["timescale"]), (int)(*this->param_map["substeps"]), false);

	// read back (async)
	NvFlexGetParticles(this->solver, get_buffer("particle_pos"), this->copy_description);
	NvFlexGetVelocities(this->solver, get_buffer("particle_vel"), this->copy_description);
	NvFlexGetPhases(this->solver, get_buffer("particle_phase"), this->copy_description);
	NvFlexGetActive(this->solver, get_buffer("particle_active"), this->copy_description);
	NvFlexGetContacts(this->solver, get_buffer("contact_planes"), get_buffer("contact_vel"), get_buffer("contact_indices"), get_buffer("contact_count"));
	NvFlexGetAnisotropy(this->solver, get_buffer("particle_ani1"), get_buffer("particle_ani2"), get_buffer("particle_ani3"), this->copy_description);
	NvFlexGetSmoothParticles(this->solver, get_buffer("particle_smooth"), this->copy_description);
}

void FlexSolver::add_mesh(Mesh mesh, NvFlexCollisionShapeType mesh_type, bool dynamic) {
	if (this->solver == nullptr) return;

	int index = this->meshes.size();
	this->meshes.push_back(mesh);

	NvFlexCollisionGeometry* geo = (NvFlexCollisionGeometry*)NvFlexMap(get_buffer("geometry"), eNvFlexMapWait);
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	int* flag = (int*)NvFlexMap(get_buffer("geometry_flags"), eNvFlexMapWait);

	flag[index] = NvFlexMakeShapeFlags(mesh_type, dynamic);
	geo[index].triMesh.mesh = mesh.get_id();
	geo[index].triMesh.scale[0] = 1;
	geo[index].triMesh.scale[1] = 1;
	geo[index].triMesh.scale[2] = 1;

	geo[index].convexMesh.mesh = mesh.get_id();
	geo[index].convexMesh.scale[0] = 1;
	geo[index].convexMesh.scale[1] = 1;
	geo[index].convexMesh.scale[2] = 1;

	pos[index] = mesh.pos;
	ppos[index] = mesh.pos;
	ang[index] = mesh.ang;
	pang[index] = mesh.ang;

	NvFlexUnmap(get_buffer("geometry"));
	NvFlexUnmap(get_buffer("geometry_pos"));
	NvFlexUnmap(get_buffer("geometry_prevpos"));
	NvFlexUnmap(get_buffer("geometry_quat"));
	NvFlexUnmap(get_buffer("geometry_prevquat"));
	NvFlexUnmap(get_buffer("geometry_flags"));
}

void FlexSolver::remove_mesh(int index) {
	if (this->solver == nullptr) return;

	// Free mesh buffers
	this->meshes[index].destroy();

	NvFlexCollisionGeometry* geo = (NvFlexCollisionGeometry*)NvFlexMap(get_buffer("geometry"), eNvFlexMapWait);
	float4* pos = (float4*)NvFlexMap(get_buffer("geometry_pos"), eNvFlexMapWait);
	float4* ppos = (float4*)NvFlexMap(get_buffer("geometry_prevpos"), eNvFlexMapWait);
	float4* ang = (float4*)NvFlexMap(get_buffer("geometry_quat"), eNvFlexMapWait);
	float4* pang = (float4*)NvFlexMap(get_buffer("geometry_prevquat"), eNvFlexMapWait);
	int* flag = (int*)NvFlexMap(get_buffer("geometry_flags"), eNvFlexMapWait);

	// "Remove" prop by shifting everything down onto it
	for (int i = index; i < this->meshes.size() - 1; i++) {
		int i2 = i + 1;
		geo[i] = geo[i2];
		pos[i] = pos[i2];
		ppos[i] = ppos[i2];
		ang[i] = ang[i2];
		pang[i] = pang[i2];
		flag[i] = flag[i2];
		this->meshes[i] = this->meshes[i2];
	}
	this->meshes.pop_back();

	NvFlexUnmap(get_buffer("geometry"));
	NvFlexUnmap(get_buffer("geometry_pos"));
	NvFlexUnmap(get_buffer("geometry_prevpos"));
	NvFlexUnmap(get_buffer("geometry_quat"));
	NvFlexUnmap(get_buffer("geometry_prevquat"));
	NvFlexUnmap(get_buffer("geometry_flags"));
}

// sets the position and angles of a mesh object. The inputted angle is Eular
void FlexSolver::update_mesh(int index, float3 new_pos, float3 new_ang) {
	if (this->solver == nullptr) return;

	this->meshes[index].update(new_pos, new_ang);
}

bool FlexSolver::set_parameter(std::string param, float number) {
	try {
		*this->param_map.at(param) = number;
		return true;
	}
	catch (std::exception e) {
		if (param == "iterations") {	// defined as an int instead of a float, so it needs to be seperate
			this->params->numIterations = (int)number;
			return true;
		}
		return false;
	}
}

// Returns NaN on failure
float FlexSolver::get_parameter(std::string param) {
	try {
		return *this->param_map.at(param);
	}
	catch (std::exception e) {
		if (param == "iterations") {	// ^
			return (float)this->params->numIterations;
		}
		return NAN;
	}
}

// Initializes a box around a FleX solver with a mins and maxs
void FlexSolver::enable_bounds(float3 mins, float3 maxs) {

	// Right
	this->params->planes[0][0] = 1.f;
	this->params->planes[0][1] = 0.f;
	this->params->planes[0][2] = 0.f;
	this->params->planes[0][3] = -mins.x;

	// Left
	this->params->planes[1][0] = -1.f;
	this->params->planes[1][1] = 0.f;
	this->params->planes[1][2] = 0.f;
	this->params->planes[1][3] = maxs.x;

	// Forward
	this->params->planes[2][0] = 0.f;
	this->params->planes[2][1] = 1.f;
	this->params->planes[2][2] = 0.f;
	this->params->planes[2][3] = -mins.y;

	// Backward
	this->params->planes[3][0] = 0.f;
	this->params->planes[3][1] = -1.f;
	this->params->planes[3][2] = 0.f;
	this->params->planes[3][3] = maxs.y;

	// Bottom
	this->params->planes[4][0] = 0.f;
	this->params->planes[4][1] = 0.f;
	this->params->planes[4][2] = 1.f;
	this->params->planes[4][3] = -mins.z;

	// Top
	this->params->planes[5][0] = 0.f;
	this->params->planes[5][1] = 0.f;
	this->params->planes[5][2] = -1.f;
	this->params->planes[5][3] = maxs.z;

	this->params->numPlanes = 6;
}

void FlexSolver::disable_bounds() {
	this->params->numPlanes = 0;
}

// Initializes a solver in a FleX library
FlexSolver::FlexSolver(NvFlexLibrary* library, int particles) {
	if (library == nullptr) return;		// Panic

	NvFlexSetSolverDescDefaults(&this->solver_description);
	this->solver_description.maxParticles = particles;
	this->solver_description.maxDiffuseParticles = 0;

	this->library = library;
	this->solver = NvFlexCreateSolver(this->library, &this->solver_description);

	default_parameters();
	map_parameters(this->params);

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

	this->hosts["particle_col"] = (float4*)malloc(sizeof(float4) * particles);
};

// Free memory
FlexSolver::~FlexSolver() {
	if (this->solver == nullptr) return;

	// Free props
	for (Mesh mesh : this->meshes) {
		mesh.destroy();
	}

	// Might cause crashing
	CMatRenderContextPtr pRenderContext(materials);
	for (IMesh* mesh : this->imeshes) {
		pRenderContext->DestroyStaticMesh(mesh);
	}

	delete this->param_map["substeps"];		// Seperate since its externally stored & not a default parameter
	delete this->param_map["timescale"];		// ^

	// Free flex buffers
	for (std::pair<std::string, NvFlexBuffer*> buffer : this->buffers) {
		NvFlexFreeBuffer(buffer.second);
	}
	NvFlexDestroySolver(this->solver);	// bye bye solver
	free(this->hosts["particle_col"]);	// color buffer is manually allocated
	this->solver = nullptr;
}

void FlexSolver::default_parameters() {
	this->params = new NvFlexParams();
	this->params->gravity[0] = 0.0f;
	this->params->gravity[1] = 0.0f;
	this->params->gravity[2] = -15.24f;	// Source gravity (600 inch^2) in m/s^2

	this->params->wind[0] = 0.0f;
	this->params->wind[1] = 0.0f;
	this->params->wind[2] = 0.0f;

	this->params->radius = 10.f;
	this->params->viscosity = 0.0f;
	this->params->dynamicFriction = 0.5f;
	this->params->staticFriction = 0.5f;
	this->params->particleFriction = 0.0f;
	this->params->freeSurfaceDrag = 0.0f;
	this->params->drag = 0.0f;
	this->params->lift = 1.0f;
	this->params->numIterations = 3;
	this->params->fluidRestDistance = 7.f;
	this->params->solidRestDistance = 7.f;

	this->params->anisotropyScale = 2.f;
	this->params->anisotropyMin = 0.0f;
	this->params->anisotropyMax = 0.15f;
	this->params->smoothing = 1.0f;

	this->params->dissipation = 0.f;
	this->params->damping = 0.0f;
	this->params->particleCollisionMargin = 0.f;
	this->params->shapeCollisionMargin = 0.f;	// Increase if lots of water pressure is expected. Higher values cause more collision clipping
	this->params->collisionDistance = 5.f; // Needed for tri-particle intersection
	this->params->sleepThreshold = 0.1f;
	this->params->shockPropagation = 0.0f;
	this->params->restitution = 0.0f;

	this->params->maxSpeed = 1e10;
	this->params->maxAcceleration = 200.0f;
	this->params->relaxationMode = eNvFlexRelaxationLocal;
	this->params->relaxationFactor = 0.0f;
	this->params->solidPressure = 0.5f;
	this->params->adhesion = 0.0f;
	this->params->cohesion = 0.005f;
	this->params->surfaceTension = 0.000001f;
	this->params->vorticityConfinement = 0.0f;
	this->params->buoyancy = 1.0f;

	this->params->diffuseThreshold = 3.f;
	this->params->diffuseBuoyancy = 1.f;
	this->params->diffuseDrag = 0.8f;
	this->params->diffuseBallistic = 0;
	this->params->diffuseLifetime = 30.0f;

	this->params->numPlanes = 0;
};

void FlexSolver::map_parameters(NvFlexParams* buffer) {
	this->param_map["gravity"] = &(buffer->gravity[2]);
	this->param_map["radius"] = &buffer->radius;
	this->param_map["viscosity"] = &buffer->viscosity;
	this->param_map["dynamic_friction"] = &buffer->dynamicFriction;
	this->param_map["static_friction"] = &buffer->staticFriction;
	this->param_map["particle_friction"] = &buffer->particleFriction;
	this->param_map["free_surface_drag"] = &buffer->freeSurfaceDrag;
	this->param_map["drag"] = &buffer->drag;
	this->param_map["lift"] = &buffer->lift;
	//this->param_map["num_iterations"] = &buffer->numIterations;
	this->param_map["fluid_rest_distance"] = &buffer->fluidRestDistance;
	this->param_map["solid_rest_distance"] = &buffer->solidRestDistance;
	this->param_map["anisotropy_scale"] = &buffer->anisotropyScale;
	this->param_map["anisotropy_min"] = &buffer->anisotropyMin;
	this->param_map["anisotropy_max"] = &buffer->anisotropyMax;
	this->param_map["dissipation"] = &buffer->dissipation;
	this->param_map["damping"] = &buffer->damping;
	this->param_map["particle_collision_margin"] = &buffer->particleCollisionMargin;
	this->param_map["shape_collision_margin"] = &buffer->shapeCollisionMargin;
	this->param_map["collision_distance"] = &buffer->collisionDistance;
	this->param_map["sleep_threshold"] = &buffer->sleepThreshold;
	this->param_map["shock_propagation"] = &buffer->shockPropagation;
	this->param_map["restitution"] = &buffer->restitution;
	this->param_map["max_speed"] = &buffer->maxSpeed;
	this->param_map["max_acceleration"] = &buffer->maxAcceleration;
	//this->param_map["relaxation_mode"] = &buffer->relaxationMode;
	this->param_map["relaxation_factor"] = &buffer->relaxationFactor;
	this->param_map["solid_pressure"] = &buffer->solidPressure;
	this->param_map["adhesion"] = &buffer->adhesion;
	this->param_map["cohesion"] = &buffer->cohesion;
	this->param_map["surface_tension"] = &buffer->surfaceTension;
	this->param_map["vorticity_confinement"] = &buffer->vorticityConfinement;
	this->param_map["buoyancy"] = &buffer->buoyancy;
	this->param_map["smoothing"] = &buffer->smoothing;

	// Extra values we store which are not stored in flexes default parameters
	this->param_map["substeps"] = new float(3);
	this->param_map["timescale"] = new float(1);
}