#pragma once
#include "flex_solver.h"

#define MAX_COLLIDERS 8192	// source can't go over this number of props so.. might as well just have it as the limit

// Struct that holds FleX solver data
void FlexSolver::add_buffer(std::string name, int type, int count) {
	NvFlexBuffer* buffer = NvFlexAllocBuffer(library, count, type, eNvFlexBufferHost);
	buffers[name] = buffer;

	// Initialize CPU buffer memory
	// this memory is automatically updated when 'NvFlexGet' is called
	hosts[name] = NvFlexMap(buffer, eNvFlexMapWait);
	memset(hosts[name], 0, type * count);
	NvFlexUnmap(buffer);
};

NvFlexBuffer* FlexSolver::get_buffer(std::string name) {
	return buffers[name];
}

//int diff = Max(n - copy_description->elementCount, 0);
//particles.erase(particles.begin() + diff, particles.end());
//copy_description->elementCount = Min(copy_description->elementCount, n);
void FlexSolver::reset() {
	// Clear particles
	copy_particles.elementCount = 0;
	copy_active.elementCount = 0;
	copy_triangles.elementCount = 0;
	copy_springs.elementCount = 0;
	particle_queue.clear();

	// Clear diffuse
	NvFlexSetDiffuseParticles(solver, NULL, NULL, 0);
	((int*)hosts["diffuse_count"])[0] = 0;

	NvFlexSetSprings(solver, NULL, NULL, NULL, 0);
	NvFlexSetDynamicTriangles(solver, NULL, NULL, 0);
}

int FlexSolver::get_active_particles() {
	return copy_particles.elementCount + particle_queue.size();
}

int FlexSolver::get_active_diffuse() {
	return ((int*)hosts["diffuse_count"])[0];
}

int FlexSolver::get_max_particles() {
	return solver_description.maxParticles;
}

int FlexSolver::get_max_diffuse_particles() {
	return solver_description.maxDiffuseParticles;
}

int FlexSolver::get_max_contacts() {
	return solver_description.maxContactsPerParticle;
}

inline void* FlexSolver::get_host(std::string name) {
	return hosts[name];
}

std::vector<FlexMesh>* FlexSolver::get_meshes() {
	return &meshes;
}

// Resets particle to base parameters
void FlexSolver::set_particle(int index, Particle particle) {
	((Vector4D*)get_host("particle_pos"))[index] = particle.pos;
	((Vector*)get_host("particle_vel"))[index] = particle.vel;
	((int*)get_host("particle_phase"))[index] = particle.phase;
	((int*)get_host("particle_active"))[index] = index;
	((Vector4D*)get_host("particle_smooth"))[index] = particle.pos;
	((Vector4D*)get_host("particle_ani0"))[index] = Vector4D(0, 0, 0, 0);
	((Vector4D*)get_host("particle_ani1"))[index] = Vector4D(0, 0, 0, 0);
	((Vector4D*)get_host("particle_ani2"))[index] = Vector4D(0, 0, 0, 0);
}

void FlexSolver::add_particle(Particle particle) {
	if (solver == nullptr) return;
	if (get_active_particles() >= get_max_particles()) return;
	
	set_particle(get_active_particles(), particle);
	particle_queue.push_back(particle);
}

inline int _grid(int x, int y, int x_size) { return y * x_size + x; }
void FlexSolver::add_cloth(Particle particle, Vector2D size) {
	particle.phase = NvFlexMakePhase(0, eNvFlexPhaseSelfCollide);	// force to cloth

	float radius = get_parameter("solid_rest_distance");
	NvFlexCopyDesc desc;
	desc.srcOffset = copy_particles.elementCount;
	desc.dstOffset = desc.srcOffset;
	desc.elementCount = 0;

	// ridiculous amount of buffers to map
	int* triangle_indices = (int*)NvFlexMap(get_buffer("triangle_indices"), eNvFlexMapWait);
	Vector* triangle_normals = (Vector*)NvFlexMap(get_buffer("triangle_normals"), eNvFlexMapWait);
	Vector4D* particle_pos = (Vector4D*)NvFlexMap(get_buffer("particle_pos"), eNvFlexMapWait);
	Vector* particle_vel = (Vector*)NvFlexMap(get_buffer("particle_vel"), eNvFlexMapWait);
	int* particle_phase = (int*)NvFlexMap(get_buffer("particle_phase"), eNvFlexMapWait);
	int* particle_active = (int*)NvFlexMap(get_buffer("particle_active"), eNvFlexMapWait);
	int* spring_indices = (int*)NvFlexMap(get_buffer("spring_indices"), eNvFlexMapWait);
	float* spring_restlengths = (float*)NvFlexMap(get_buffer("spring_restlengths"), eNvFlexMapWait);
	float* spring_stiffness = (float*)NvFlexMap(get_buffer("spring_stiffness"), eNvFlexMapWait);

	for (int y = 0; y < size.y; y++) {
		for (int x = 0; x < size.x; x++) {
			if (get_active_particles() >= get_max_particles()) break;

			// Add particle
			int index = copy_particles.elementCount++;
			particle_pos[index] = particle.pos + Vector4D(x * radius, y * radius, 0, 0);
			particle_vel[index] = particle.vel;
			particle_phase[index] = particle.phase;
			particle_active[index] = index;
			desc.elementCount++;
			
			// Add triangles
			if (x > 0 && y > 0) {
				triangle_indices[copy_triangles.elementCount * 3	] = desc.srcOffset + _grid(x - 1, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 1] = desc.srcOffset + _grid(x, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 2] = desc.srcOffset + _grid(x, y, size.x);
				triangle_normals[copy_triangles.elementCount] = Vector(0, 0, 1);
				copy_triangles.elementCount++;
				
				triangle_indices[copy_triangles.elementCount * 3	] = desc.srcOffset + _grid(x - 1, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 1] = desc.srcOffset + _grid(x, y, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 2] = desc.srcOffset + _grid(x - 1, y, size.x);
				triangle_normals[copy_triangles.elementCount] = Vector(0, 0, 1);
				copy_triangles.elementCount++;
			}
			
			// Create spring between particle x,y and x-1,y
			if (x > 0) {
				int spring_index0 = desc.srcOffset + _grid(x, y, size.x);
				int spring_index1 = desc.srcOffset + _grid(x - 1, y, size.x);
				spring_indices[copy_springs.elementCount * 2] = spring_index1;
				spring_indices[copy_springs.elementCount * 2 + 1] = spring_index0;
				spring_restlengths[copy_springs.elementCount] = particle_pos[spring_index0].AsVector3D().DistTo(particle_pos[spring_index1].AsVector3D());
				spring_stiffness[copy_springs.elementCount] = 1;
				copy_springs.elementCount++;
			}

			// Create spring between particle x,y and x,y-1
			if (y > 0) {
				int spring_index0 = desc.srcOffset + _grid(x, y, size.x);
				int spring_index1 = desc.srcOffset + _grid(x, y - 1, size.x);
				spring_indices[copy_springs.elementCount * 2] = spring_index0;
				spring_indices[copy_springs.elementCount * 2 + 1] = spring_index1;
				spring_restlengths[copy_springs.elementCount] = particle_pos[spring_index0].AsVector3D().DistTo(particle_pos[spring_index1].AsVector3D());
				spring_stiffness[copy_springs.elementCount] = 1;
				copy_springs.elementCount++;
			}
		}
	}

	NvFlexUnmap(get_buffer("triangle_indices"));
	NvFlexUnmap(get_buffer("triangle_normals"));
	NvFlexUnmap(get_buffer("particle_pos"));
	NvFlexUnmap(get_buffer("particle_vel"));
	NvFlexUnmap(get_buffer("particle_phase"));
	NvFlexUnmap(get_buffer("particle_active"));
	NvFlexUnmap(get_buffer("spring_indices"));
	NvFlexUnmap(get_buffer("spring_restlengths"));
	NvFlexUnmap(get_buffer("spring_stiffness"));

	// Update particle information
	NvFlexSetParticles(solver, get_buffer("particle_pos"), &desc);
	NvFlexSetVelocities(solver, get_buffer("particle_vel"), &desc);
	NvFlexSetPhases(solver, get_buffer("particle_phase"), &desc);
	NvFlexSetActive(solver, get_buffer("particle_active"), &desc);
	NvFlexSetActiveCount(solver, copy_particles.elementCount);
	NvFlexSetDynamicTriangles(solver, get_buffer("triangle_indices"), get_buffer("triangle_normals"), copy_triangles.elementCount);
	NvFlexSetSprings(solver, get_buffer("spring_indices"), get_buffer("spring_restlengths"), get_buffer("spring_stiffness"), copy_springs.elementCount);
}

void FlexSolver::add_force_field(NvFlexExtForceField force_field) {
	force_field_queue.push_back(force_field);
}

// ticks the solver
bool FlexSolver::tick(float dt, NvFlexMapFlags wait) {
	if (solver == nullptr) return false;

	// Update collision geometry
	NvFlexCollisionGeometry* geometry = (NvFlexCollisionGeometry*)get_host("geometry");
	Vector4D* geometry_pos = (Vector4D*)get_host("geometry_pos");
	Vector4D* geometry_prevpos = (Vector4D*)get_host("geometry_prevpos");
	Vector4D* geometry_ang = (Vector4D*)get_host("geometry_quat");
	Vector4D* geometry_prevang = (Vector4D*)get_host("geometry_prevquat");
	int* geometry_flags = (int*)get_host("geometry_flags");

	for (int i = 0; i < meshes.size(); i++) {
		FlexMesh mesh = meshes[i];

		geometry_flags[i] = mesh.get_flags();
		geometry[i].triMesh.mesh = mesh.get_id();
		geometry[i].triMesh.scale[0] = 1;
		geometry[i].triMesh.scale[1] = 1;
		geometry[i].triMesh.scale[2] = 1;

		geometry[i].convexMesh.mesh = mesh.get_id();
		geometry[i].convexMesh.scale[0] = 1;
		geometry[i].convexMesh.scale[1] = 1;
		geometry[i].convexMesh.scale[2] = 1;

		geometry_prevpos[i] = mesh.get_ppos();
		geometry_pos[i] = mesh.get_pos();

		geometry_prevang[i] = mesh.get_pang();
		geometry_ang[i] = mesh.get_ang();

		meshes[i].update();
	}

	// Avoid ticking if the deltatime ends up being zero, as it invalidates the simulation
	dt *= get_parameter("timescale");
	if (dt > 0 && get_active_particles() > 0) {

		// Map positions to CPU memory
		Vector4D* particle_pos = (Vector4D*)NvFlexMap(get_buffer("particle_pos"), wait);
		if (particle_pos) {
			if (particle_queue.empty()) {
				NvFlexUnmap(get_buffer("particle_pos"));
			} else {
				// Add queued particles
				for (int i = 0; i < particle_queue.size(); i++) {
					int particle_index = copy_particles.elementCount + i;
					particle_pos[particle_index] = particle_queue[i].pos;
					//set_particle(particle_index, particle_queue[i]);
				}

				NvFlexUnmap(get_buffer("particle_pos"));

				// Only copy what we just added
				NvFlexCopyDesc desc;
				desc.dstOffset = copy_particles.elementCount;
				desc.elementCount = particle_queue.size();
				desc.srcOffset = desc.dstOffset;

				// Update particle information
				NvFlexSetParticles(solver, get_buffer("particle_pos"), &desc);
				NvFlexSetVelocities(solver, get_buffer("particle_vel"), &desc);
				NvFlexSetPhases(solver, get_buffer("particle_phase"), &desc);
				NvFlexSetActive(solver, get_buffer("particle_active"), &desc);
				NvFlexSetActiveCount(solver, get_active_particles());

				copy_particles.elementCount += particle_queue.size();
				particle_queue.clear();
			}
		} else {
			return false;
		}

		// write to device (async)
		NvFlexSetShapes(
			solver,
			get_buffer("geometry"),
			get_buffer("geometry_pos"),
			get_buffer("geometry_quat"),
			get_buffer("geometry_prevpos"),
			get_buffer("geometry_prevquat"),
			get_buffer("geometry_flags"),
			meshes.size()
		);
		NvFlexSetParams(solver, params);
		NvFlexExtSetForceFields(force_field_callback, force_field_queue.data(), force_field_queue.size());

		// tick
		NvFlexUpdateSolver(solver, dt, (int)get_parameter("substeps"), false);

		// read back (async)
		NvFlexGetParticles(solver, get_buffer("particle_pos"), &copy_particles);
		NvFlexGetDiffuseParticles(solver, get_buffer("diffuse_pos"), get_buffer("diffuse_vel"), get_buffer("diffuse_count"));
		NvFlexGetDynamicTriangles(solver, NULL, get_buffer("triangle_normals"), copy_triangles.elementCount);

		if (get_parameter("anisotropy_scale") != 0) {
			NvFlexGetAnisotropy(solver, get_buffer("particle_ani0"), get_buffer("particle_ani1"), get_buffer("particle_ani2"), &copy_particles);
		}

		if (get_parameter("smoothing") != 0) {
			NvFlexGetSmoothParticles(solver, get_buffer("particle_smooth"), &copy_particles);
		}

		if (get_parameter("reaction_forces") > 1) {
			NvFlexGetVelocities(solver, get_buffer("particle_vel"), &copy_particles);
			NvFlexGetContacts(solver, get_buffer("contact_planes"), get_buffer("contact_vel"), get_buffer("contact_indices"), get_buffer("contact_count"));
		}

		force_field_queue.clear();

		return true;
	} else {
		force_field_queue.clear();

		return false;
	}
}

void FlexSolver::add_mesh(FlexMesh mesh) {
	if (solver == nullptr) return;

	meshes.push_back(mesh);
}

// TODO(?): Use a linked list instead of a vector
void FlexSolver::remove_mesh(int id) {
	if (solver == nullptr) return;

	for (int i = meshes.size() - 1; i >= 0; i--) {
		if (meshes[i].get_entity_id() == id) {
			// Free mesh buffers
			meshes[i].destroy(library);
			meshes.erase(meshes.begin() + i);
		}
	}
}

// sets the position and angles of a mesh object. The inputted angle is Eular
void FlexSolver::update_mesh(int index, Vector new_pos, QAngle new_ang) {
	if (solver == nullptr) return;
	if (index < 0 || index >= meshes.size()) return;	// Invalid

	meshes[index].set_pos(new_pos);
	meshes[index].set_ang(new_ang);
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
void FlexSolver::enable_bounds(Vector mins, Vector maxs) {

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
	solver_description.maxDiffuseParticles = particles;

	this->library = library;
	solver = NvFlexCreateSolver(library, &solver_description);

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
	params->lift = 0.0f;
	params->numIterations = 3;
	params->fluidRestDistance = 6.5f;
	params->solidRestDistance = 6.5f;

	params->anisotropyScale = 1.f;
	params->anisotropyMin = 0.2f;
	params->anisotropyMax = 2.f;
	params->smoothing = 1.0f;

	params->dissipation = 0.f;
	params->damping = 0.0f;
	params->particleCollisionMargin = 0.f;
	params->shapeCollisionMargin = 0.f;	// Increase if lots of water pressure is expected. Higher values cause more collision clipping
	params->collisionDistance = 5.f; // Needed for tri-particle intersection
	params->sleepThreshold = 0.1f;
	params->shockPropagation = 0.0f;
	params->restitution = 0.0f;

	params->maxSpeed = 1e5;
	params->maxAcceleration = 1e5;
	params->relaxationMode = eNvFlexRelaxationLocal;
	params->relaxationFactor = 0.25f;	// only works with eNvFlexRelaxationGlobal
	params->solidPressure = 0.5f;
	params->adhesion = 0.0f;
	params->cohesion = 0.01f;
	params->surfaceTension = 0.000001f;
	params->vorticityConfinement = 0.0f;
	params->buoyancy = 1.0f;

	params->diffuseThreshold = 100.f;
	params->diffuseBuoyancy = 1.f;
	params->diffuseDrag = 0.8f;
	params->diffuseBallistic = 2;
	params->diffuseLifetime = 5.f;	// not actually in seconds

	params->numPlanes = 0;

	param_map["gravity"] = &(params->gravity[2]);
	param_map["radius"] = &params->radius;
	param_map["viscosity"] = &params->viscosity;
	param_map["dynamic_friction"] = &params->dynamicFriction;
	param_map["static_friction"] = &params->staticFriction;
	param_map["particle_friction"] = &params->particleFriction;
	param_map["free_surface_drag"] = &params->freeSurfaceDrag;
	param_map["drag"] = &params->drag;
	param_map["lift"] = &params->lift;
	//param_map["iterations"] = &params->numIterations;				// integer, cant map
	param_map["fluid_rest_distance"] = &params->fluidRestDistance;
	param_map["solid_rest_distance"] = &params->solidRestDistance;
	param_map["anisotropy_scale"] = &params->anisotropyScale;
	param_map["anisotropy_min"] = &params->anisotropyMin;
	param_map["anisotropy_max"] = &params->anisotropyMax;
	param_map["smoothing"] = &params->smoothing;
	param_map["dissipation"] = &params->dissipation;
	param_map["damping"] = &params->damping;
	param_map["particle_collision_margin"] = &params->particleCollisionMargin;
	param_map["shape_collision_margin"] = &params->shapeCollisionMargin;
	param_map["collision_distance"] = &params->collisionDistance;
	param_map["sleep_threshold"] = &params->sleepThreshold;
	param_map["shock_propagation"] = &params->shockPropagation;
	param_map["restitution"] = &params->restitution;
	param_map["max_speed"] = &params->maxSpeed;
	param_map["max_acceleration"] = &params->maxAcceleration;
	//param_map["relaxation_mode"] = &params->relaxationMode;		// ^
	param_map["relaxation_factor"] = &params->relaxationFactor;
	param_map["solid_pressure"] = &params->solidPressure;
	param_map["adhesion"] = &params->adhesion;
	param_map["cohesion"] = &params->cohesion;
	param_map["surface_tension"] = &params->surfaceTension;
	param_map["vorticity_confinement"] = &params->vorticityConfinement;
	param_map["buoyancy"] = &params->buoyancy;
	param_map["diffuse_threshold"] = &params->diffuseThreshold;
	param_map["diffuse_buoyancy"] = &params->diffuseBuoyancy;
	param_map["diffuse_drag"] = &params->diffuseDrag;
	//param_map["diffuse_ballistic"] = &params->diffuseBallistic;	// ^
	param_map["diffuse_lifetime"] = &params->diffuseLifetime;
	// Extra values we store which are not stored in flexes default parameters
	param_map["substeps"] = new float(3);
	param_map["timescale"] = new float(1);
	param_map["reaction_forces"] = new float(1);

	// FleX GPU Buffers
	add_buffer("particle_pos", sizeof(Vector4D), particles);
	add_buffer("particle_vel", sizeof(Vector), particles);
	add_buffer("particle_phase", sizeof(int), particles);
	add_buffer("particle_active", sizeof(int), particles);
	add_buffer("particle_smooth", sizeof(Vector4D), particles);

	add_buffer("geometry", sizeof(NvFlexCollisionGeometry), MAX_COLLIDERS);
	add_buffer("geometry_pos", sizeof(Vector4D), MAX_COLLIDERS);
	add_buffer("geometry_prevpos", sizeof(Vector4D), MAX_COLLIDERS);
	add_buffer("geometry_quat", sizeof(Vector4D), MAX_COLLIDERS);
	add_buffer("geometry_prevquat", sizeof(Vector4D), MAX_COLLIDERS);
	add_buffer("geometry_flags", sizeof(int), MAX_COLLIDERS);

	add_buffer("contact_planes", sizeof(Vector4D), particles * get_max_contacts());
	add_buffer("contact_vel", sizeof(Vector4D), particles * get_max_contacts());
	add_buffer("contact_count", sizeof(int), particles);
	add_buffer("contact_indices", sizeof(int), particles);

	add_buffer("particle_ani0", sizeof(Vector4D), particles);
	add_buffer("particle_ani1", sizeof(Vector4D), particles);
	add_buffer("particle_ani2", sizeof(Vector4D), particles);

	add_buffer("diffuse_pos", sizeof(Vector4D), solver_description.maxDiffuseParticles);
	add_buffer("diffuse_vel", sizeof(Vector4D), solver_description.maxDiffuseParticles);
	add_buffer("diffuse_count", sizeof(int), 1);	// "this may be updated by the GPU which is why it is passed back in a buffer"

	add_buffer("triangle_indices", sizeof(int), particles * 3 * 2);
	add_buffer("triangle_normals", sizeof(Vector), particles * 2);
	
	add_buffer("spring_indices", sizeof(int), particles * 2 * 2);	// 2 springs per particle, 2 indices
	add_buffer("spring_restlengths", sizeof(float), particles * 2);
	add_buffer("spring_stiffness", sizeof(float), particles * 2);

	force_field_callback = NvFlexExtCreateForceFieldCallback(solver);
};

// Free memory
FlexSolver::~FlexSolver() {
	if (solver == nullptr) return;

	// Free props
	for (FlexMesh mesh : meshes)
		mesh.destroy(library);
	meshes.clear();

	delete param_map["substeps"];		// Seperate since its externally stored & not a default parameter
	delete param_map["timescale"];		// ^
	delete param_map["reaction_forces"];// ^
	delete params;

	NvFlexExtDestroyForceFieldCallback(force_field_callback);

	// Free buffers / hosts
	for (std::pair<std::string, NvFlexBuffer*> buffer : buffers) 
		NvFlexFreeBuffer(buffer.second);

	NvFlexDestroySolver(solver);	// bye bye solver
	solver = nullptr;
}