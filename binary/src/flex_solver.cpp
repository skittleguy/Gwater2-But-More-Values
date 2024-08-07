#pragma once
#include "flex_solver.h"

#define MAX_COLLIDERS 8192	// source can't go over this number of props so.. might as well just have it as the limit

template <typename T> NvFlexBuffer* FlexBuffers::init(NvFlexLibrary* library, T** host, int count) {
	NvFlexBuffer* buffer = NvFlexAllocBuffer(library, count, sizeof(T), eNvFlexBufferHost);

	// Initialize CPU buffer memory
	// this memory is automatically updated when 'NvFlexGet' is called
	void* mapped = NvFlexMap(buffer, eNvFlexMapWait);
	memset(mapped, 0, sizeof(T) * count);
	NvFlexUnmap(buffer);

	buffers.push_back(buffer);
	if (host != nullptr) *host = (T*)mapped;
	return buffer;
}

void FlexBuffers::destroy() {
	for (NvFlexBuffer* buffer : buffers) NvFlexFreeBuffer(buffer);
}

//int diff = Max(n - copy_description->elementCount, 0);
//particles.erase(particles.begin() + diff, particles.end());
//copy_description->elementCount = Min(copy_description->elementCount, n);

// clears all particles
void FlexSolver::reset() {
	reset_cloth();
	copy_particles.elementCount = 0;
	copy_active.elementCount = 0;
	particle_queue.clear();

	// clear diffuse
	NvFlexSetDiffuseParticles(solver, NULL, NULL, 0);
	hosts.diffuse_count[0] = 0;
}

void FlexSolver::reset_cloth() {
	copy_triangles.elementCount = 0;
	copy_springs.elementCount = 0;
	NvFlexSetSprings(solver, NULL, NULL, NULL, 0);
}

int FlexSolver::get_active_particles() {
	return copy_particles.elementCount + particle_queue.size();
}

int FlexSolver::get_active_triangles() {
	return copy_triangles.elementCount;
}

int FlexSolver::get_active_diffuse() {
	return hosts.diffuse_count[0];
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

std::vector<FlexMesh>* FlexSolver::get_meshes() {
	return &meshes;
}

// Resets particle to base parameters
void FlexSolver::set_particle(int index, Particle particle) {
	hosts.particle_pos[index] = particle.pos;
	hosts.particle_smooth[index] = particle.pos;
	hosts.particle_vel[index] = particle.vel;
	hosts.particle_phase[index] = particle.phase;
	hosts.particle_active[index] = index;
	hosts.particle_ani0[index] = Vector4D(0, 0, 0, 0);
	hosts.particle_ani1[index] = Vector4D(0, 0, 0, 0);
	hosts.particle_ani2[index] = Vector4D(0, 0, 0, 0);
}

void FlexSolver::add_particle(Particle particle) {
	if (solver == nullptr) return;
	if (get_active_particles() >= get_max_particles()) return;
	
	set_particle(get_active_particles(), particle);
	particle_queue.push_back(particle);
}

inline int _grid(int x, int y, int x_size) { return y * x_size + x; }
void FlexSolver::add_cloth(Particle particle, Vector2D size) {
	float radius = get_parameter("solid_rest_distance");
	particle.phase = FlexPhase::CLOTH;	// force to cloth
	particle.pos.x -= size.x * radius / 2.0;
	particle.pos.y -= size.y * radius / 2.0;
	NvFlexCopyDesc desc;
	desc.srcOffset = copy_particles.elementCount;
	desc.dstOffset = desc.srcOffset;
	desc.elementCount = 0;

	// ridiculous amount of buffers to map
	int* triangle_indices = (int*)NvFlexMap(buffers.triangle_indices, eNvFlexMapWait);
	Vector4D* particle_pos = (Vector4D*)NvFlexMap(buffers.particle_pos, eNvFlexMapWait);
	Vector* particle_vel = (Vector*)NvFlexMap(buffers.particle_vel, eNvFlexMapWait);
	int* particle_phase = (int*)NvFlexMap(buffers.particle_phase, eNvFlexMapWait);
	int* particle_active = (int*)NvFlexMap(buffers.particle_active, eNvFlexMapWait);
	int* spring_indices = (int*)NvFlexMap(buffers.spring_indices, eNvFlexMapWait);
	float* spring_restlengths = (float*)NvFlexMap(buffers.spring_restlengths, eNvFlexMapWait);
	float* spring_stiffness = (float*)NvFlexMap(buffers.spring_stiffness, eNvFlexMapWait);

	for (int y = 0; y < size.y; y++) {
		for (int x = 0; x < size.x; x++) {
			if (get_active_particles() >= get_max_particles()) break;

			// Add particle
			int index = copy_particles.elementCount++;
			particle_pos[index] = particle.pos + Vector4D(x * radius, y * radius, 0, 0);
			particle_vel[index] = particle.vel;
			particle_phase[index] = particle.phase;	// force to cloth
			particle_active[index] = index;
			desc.elementCount++;
			
			// Add triangles
			if (x > 0 && y > 0) {
				triangle_indices[copy_triangles.elementCount * 3	] = desc.srcOffset + _grid(x, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 1] = desc.srcOffset + _grid(x - 1, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 2] = desc.srcOffset + _grid(x, y, size.x);
				copy_triangles.elementCount++;
				
				triangle_indices[copy_triangles.elementCount * 3	] = desc.srcOffset + _grid(x, y, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 1] = desc.srcOffset + _grid(x - 1, y - 1, size.x);
				triangle_indices[copy_triangles.elementCount * 3 + 2] = desc.srcOffset + _grid(x - 1, y, size.x);
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

	NvFlexUnmap(buffers.triangle_indices);
	NvFlexUnmap(buffers.particle_pos);
	NvFlexUnmap(buffers.particle_vel);
	NvFlexUnmap(buffers.particle_phase);
	NvFlexUnmap(buffers.particle_active);
	NvFlexUnmap(buffers.spring_indices);
	NvFlexUnmap(buffers.spring_restlengths);
	NvFlexUnmap(buffers.spring_stiffness);

	// Update particle information
	NvFlexSetParticles(solver, buffers.particle_pos, &desc);
	NvFlexSetVelocities(solver, buffers.particle_vel, &desc);
	NvFlexSetPhases(solver, buffers.particle_phase, &desc);
	NvFlexSetActive(solver, buffers.particle_active, &desc);
	NvFlexSetActiveCount(solver, copy_particles.elementCount);
	NvFlexSetDynamicTriangles(solver, buffers.triangle_indices, NULL, copy_triangles.elementCount);
	NvFlexSetSprings(solver, buffers.spring_indices, buffers.spring_restlengths, buffers.spring_stiffness, copy_springs.elementCount);
}

void FlexSolver::add_force_field(NvFlexExtForceField force_field) {
	force_field_queue.push_back(force_field);
}

// ticks the solver
bool FlexSolver::tick(float dt, NvFlexMapFlags wait) {
	if (solver == nullptr) return false;

	// Update collision geometry
	//NvFlexCollisionGeometry* geometry = (NvFlexCollisionGeometry*)get_host("geometry");
	for (int i = 0; i < meshes.size(); i++) {
		FlexMesh mesh = meshes[i];

		hosts.geometry_flags[i] = mesh.get_flags();
		hosts.geometry[i].triMesh.mesh = mesh.get_id();
		hosts.geometry[i].triMesh.scale[0] = 1;
		hosts.geometry[i].triMesh.scale[1] = 1;
		hosts.geometry[i].triMesh.scale[2] = 1;

		hosts.geometry[i].convexMesh.mesh = mesh.get_id();
		hosts.geometry[i].convexMesh.scale[0] = 1;
		hosts.geometry[i].convexMesh.scale[1] = 1;
		hosts.geometry[i].convexMesh.scale[2] = 1;

		hosts.geometry_prevpos[i] = mesh.get_ppos();
		hosts.geometry_pos[i] = mesh.get_pos();

		hosts.geometry_prevang[i] = mesh.get_pang();
		hosts.geometry_ang[i] = mesh.get_ang();

		meshes[i].update();
	}

	// Avoid ticking if the deltatime ends up being zero, as it invalidates the simulation
	dt *= get_parameter("timescale");
	if (dt > 0 && get_active_particles() > 0) {

		// Map positions to CPU memory
		Vector4D* particle_pos = (Vector4D*)NvFlexMap(buffers.particle_smooth, wait);
		if (particle_pos) {
			if (particle_queue.empty()) {
				NvFlexUnmap(buffers.particle_smooth);
			} else {
				// Add queued particles
				for (int i = 0; i < particle_queue.size(); i++) {
					int particle_index = copy_particles.elementCount + i;
					//particle_pos[particle_index] = particle_queue[i].pos;
					set_particle(particle_index, particle_queue[i]);
				}

				NvFlexUnmap(buffers.particle_smooth);

				// Only copy what we just added
				NvFlexCopyDesc desc;
				desc.dstOffset = copy_particles.elementCount;
				desc.elementCount = particle_queue.size();
				desc.srcOffset = desc.dstOffset;

				// Update particle information
				NvFlexSetParticles(solver, buffers.particle_pos, &desc);
				NvFlexSetVelocities(solver, buffers.particle_vel, &desc);
				NvFlexSetPhases(solver, buffers.particle_phase, &desc);
				NvFlexSetActive(solver, buffers.particle_active, &desc);
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
			buffers.geometry,
			buffers.geometry_pos,
			buffers.geometry_quat,
			buffers.geometry_prevpos,
			buffers.geometry_prevquat,
			buffers.geometry_flags,
			meshes.size()
		);
		NvFlexSetParams(solver, params);
		NvFlexExtSetForceFields(force_field_callback, force_field_queue.data(), force_field_queue.size());

		// tick
		NvFlexUpdateSolver(solver, dt, (int)get_parameter("substeps"), false);

		// read back (async)
		NvFlexGetParticles(solver, buffers.particle_pos, &copy_particles);
		NvFlexGetDiffuseParticles(solver, buffers.diffuse_pos, buffers.diffuse_vel, buffers.diffuse_count);

		if (get_active_triangles() > 0) {
			NvFlexGetNormals(solver, buffers.triangle_normals, &copy_particles);
		}

		if (get_parameter("anisotropy_scale") != 0) {
			NvFlexGetAnisotropy(solver, buffers.particle_ani0, buffers.particle_ani1, buffers.particle_ani2, &copy_particles);
		}

		if (get_parameter("smoothing") != 0) {
			NvFlexGetSmoothParticles(solver, buffers.particle_smooth, &copy_particles);
		}

		if (get_parameter("reaction_forces") > 1) {
			NvFlexGetVelocities(solver, buffers.particle_vel, &copy_particles);
			NvFlexGetContacts(solver, buffers.contact_planes, buffers.contact_vel, buffers.contact_indices, buffers.contact_count);
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
	buffers.particle_pos = buffers.init(library, &hosts.particle_pos, particles);
	buffers.particle_vel = buffers.init(library, &hosts.particle_vel, particles);
	buffers.particle_phase = buffers.init(library, &hosts.particle_phase, particles);
	buffers.particle_active = buffers.init(library, &hosts.particle_active, particles);
	buffers.particle_smooth = buffers.init(library, &hosts.particle_smooth, particles);

	buffers.geometry = buffers.init(library, &hosts.geometry, MAX_COLLIDERS);
	buffers.geometry_pos = buffers.init(library, &hosts.geometry_pos, MAX_COLLIDERS);
	buffers.geometry_prevpos = buffers.init(library, &hosts.geometry_prevpos, MAX_COLLIDERS);
	buffers.geometry_quat = buffers.init(library, &hosts.geometry_ang, MAX_COLLIDERS);
	buffers.geometry_prevquat = buffers.init(library, &hosts.geometry_prevang, MAX_COLLIDERS);
	buffers.geometry_flags = buffers.init(library, &hosts.geometry_flags, MAX_COLLIDERS);

	buffers.contact_planes = buffers.init(library, &hosts.contact_planes, particles * get_max_contacts());
	buffers.contact_vel = buffers.init(library, &hosts.contact_vel, particles * get_max_contacts());
	buffers.contact_count = buffers.init(library, &hosts.contact_count, particles);
	buffers.contact_indices = buffers.init(library, &hosts.contact_indices, particles);

	buffers.particle_ani0 = buffers.init(library, &hosts.particle_ani0, particles);
	buffers.particle_ani1 = buffers.init(library, &hosts.particle_ani1, particles);
	buffers.particle_ani2 = buffers.init(library, &hosts.particle_ani2, particles);

	buffers.diffuse_pos = buffers.init(library, &hosts.diffuse_pos, solver_description.maxDiffuseParticles);
	buffers.diffuse_vel = buffers.init(library, &hosts.diffuse_vel, solver_description.maxDiffuseParticles);
	buffers.diffuse_count = buffers.init(library, &hosts.diffuse_count, 1);	// "this may be updated by the GPU which is why it is passed back in a buffer"

	buffers.triangle_indices = buffers.init(library, &hosts.triangle_indices, particles * 3 * 2); // 3 indices per triangle, maximum of 2 triangles per particle
	buffers.triangle_normals = buffers.init(library, &hosts.triangle_normals, particles); // per-particle normals

	buffers.spring_indices = buffers.init(library, &hosts.spring_indices, particles * 2 * 2); // 2 spring indices, max of 2 springs per particle
	buffers.spring_restlengths = buffers.init(library, &hosts.spring_restlengths, particles * 2);
	buffers.spring_stiffness = buffers.init(library, &hosts.spring_stiffness, particles * 2);

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
	buffers.destroy();

	NvFlexDestroySolver(solver);	// bye bye solver
	solver = nullptr;
}