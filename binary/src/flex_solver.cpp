#pragma once
#include "flex_solver.h"

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

	copy_active.elementCount = 0;
	particle_queue.clear();
	particle_queue_index = 0;

	// clear diffuse
	hosts.diffuse_count = (int*)NvFlexMap(buffers.diffuse_count, eNvFlexMapWait);
	hosts.diffuse_count[0] = 0;
	NvFlexUnmap(buffers.diffuse_count);
	NvFlexSetDiffuseParticles(solver, NULL, NULL, 0);

	memset(hosts.particle_lifetime, 0, sizeof(float) * get_max_particles());
}

void FlexSolver::reset_cloth() {
	copy_triangles.elementCount = 0;
	copy_springs.elementCount = 0;
	NvFlexSetSprings(solver, NULL, NULL, NULL, 0);

	// kill all cloth
	for (int i = 0; i < copy_active.elementCount; i++) {
		int active_index = hosts.particle_active[i];
		if (hosts.particle_phase[active_index] == FlexPhase::CLOTH) {
			hosts.particle_lifetime[active_index] = 0;
		}
	}
}

int FlexSolver::get_active_particles() {
	return copy_active.elementCount + particle_queue.size();
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

// Finds next avaliable particle, value outputted as particle_queue_index variable
void FlexSolver::next_particle() {
	while (hosts.particle_lifetime[particle_queue_index] > 0) {
		particle_queue_index++;

		// This should NEVER run.. but.. just incase.. 
		if (particle_queue_index >= get_max_particles()) {
			Warning("[GWater2 Internal Error]: PARTICLE QUEUE OVERFLOWED, EXITING! THIS SHOULD NEVER HAPPEN!\n");
			particle_queue_index = 0;
			break;
		}
	}
}

// Resets particle to base parameters
void FlexSolver::set_particle(int particle_index, int active_index, Particle particle) {
	hosts.particle_pos[particle_index] = particle.pos;
	hosts.particle_smooth[particle_index] = particle.pos;
	hosts.particle_vel[particle_index] = particle.vel;
	hosts.particle_phase[particle_index] = particle.phase;
	hosts.particle_lifetime[particle_index] = particle.lifetime;
	hosts.particle_ani0[particle_index] = Vector4D(0, 0, 0, 0);
	hosts.particle_ani1[particle_index] = Vector4D(0, 0, 0, 0);
	hosts.particle_ani2[particle_index] = Vector4D(0, 0, 0, 0);
	hosts.particle_active[active_index] = particle_index;
}

void FlexSolver::add_particle(Particle particle) {
	if (get_active_particles() >= get_max_particles()) return;
	
	next_particle();
	set_particle(particle_queue_index, get_active_particles(), particle);
	particle_queue[particle_queue_index] = particle;
}

inline int _grid(int x, int y, int x_size) { return y * x_size + x; }
void FlexSolver::add_cloth(VMatrix translation, Vector2D size, Particle particle) {
	particle.phase = FlexPhase::CLOTH;	// force to cloth
	particle.lifetime = FLT_MAX;		// no die

	NvFlexGetParticles(solver, buffers.particle_pos, NULL);
	NvFlexGetVelocities(solver, buffers.particle_vel, NULL);

	// ridiculous amount of buffers to map
	int* triangle_indices = (int*)NvFlexMap(buffers.triangle_indices, eNvFlexMapWait);
	Vector4D* particle_pos = (Vector4D*)NvFlexMap(buffers.particle_pos, eNvFlexMapWait);
	Vector* particle_vel = (Vector*)NvFlexMap(buffers.particle_vel, eNvFlexMapWait);
	int* particle_phase = (int*)NvFlexMap(buffers.particle_phase, eNvFlexMapWait);
	int* particle_active = (int*)NvFlexMap(buffers.particle_active, eNvFlexMapWait);
	int* spring_indices = (int*)NvFlexMap(buffers.spring_indices, eNvFlexMapWait);
	float* spring_restlengths = (float*)NvFlexMap(buffers.spring_restlengths, eNvFlexMapWait);
	float* spring_stiffness = (float*)NvFlexMap(buffers.spring_stiffness, eNvFlexMapWait);

	int* activated = (int*)malloc(sizeof(int) * size.x * size.y);	// TODO: would using alloca be valid here?

	for (int y = 0; y < size.y; y++) {
		for (int x = 0; x < size.x; x++) {
			if (get_active_particles() >= get_max_particles()) break;

			next_particle();

			// Add particle
			Vector pos = translation * Vector(x - size.x / 2.0, y - size.y / 2.0, 0);
			particle_pos[particle_queue_index] = Vector4D(pos.x, pos.y, pos.z, particle.pos.w);
			particle_vel[particle_queue_index] = particle.vel;
			particle_phase[particle_queue_index] = particle.phase;	// force to cloth
			particle_active[copy_active.elementCount++] = particle_queue_index;
			hosts.particle_lifetime[particle_queue_index] = particle.lifetime;
			activated[_grid(x, y, size.x)] = particle_queue_index;
			
			// Add triangles
			if (x > 0 && y > 0) {
				triangle_indices[copy_triangles.elementCount * 3	] = activated[_grid(x, y - 1, size.x)];
				triangle_indices[copy_triangles.elementCount * 3 + 1] = activated[_grid(x - 1, y - 1, size.x)];
				triangle_indices[copy_triangles.elementCount * 3 + 2] = activated[_grid(x, y, size.x)];
				copy_triangles.elementCount++;
				
				triangle_indices[copy_triangles.elementCount * 3	] = activated[_grid(x, y, size.x)];
				triangle_indices[copy_triangles.elementCount * 3 + 1] = activated[_grid(x - 1, y - 1, size.x)];
				triangle_indices[copy_triangles.elementCount * 3 + 2] = activated[_grid(x - 1, y, size.x)];
				copy_triangles.elementCount++;
			}
			
			// Create spring between particle x,y and x-1,y
			if (x > 0) {
				int spring_index0 = activated[_grid(x, y, size.x)];
				int spring_index1 = activated[_grid(x - 1, y, size.x)];
				spring_indices[copy_springs.elementCount * 2] = spring_index1;
				spring_indices[copy_springs.elementCount * 2 + 1] = spring_index0;
				spring_restlengths[copy_springs.elementCount] = particle_pos[spring_index0].AsVector3D().DistTo(particle_pos[spring_index1].AsVector3D());
				spring_stiffness[copy_springs.elementCount] = 1;
				copy_springs.elementCount++;
			}

			// Create spring between particle x,y and x,y-1
			if (y > 0) {
				int spring_index0 = activated[_grid(x, y, size.x)];
				int spring_index1 = activated[_grid(x, y - 1, size.x)];
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
	NvFlexSetParticles(solver, buffers.particle_pos, NULL);
	NvFlexSetVelocities(solver, buffers.particle_vel, NULL);
	NvFlexSetPhases(solver, buffers.particle_phase, NULL);
	NvFlexSetActive(solver, buffers.particle_active, NULL);
	NvFlexSetActiveCount(solver, copy_active.elementCount);
	NvFlexSetDynamicTriangles(solver, buffers.triangle_indices, NULL, copy_triangles.elementCount);
	NvFlexSetSprings(solver, buffers.spring_indices, buffers.spring_restlengths, buffers.spring_stiffness, copy_springs.elementCount);
	free(activated);
}

void FlexSolver::add_force_field(NvFlexExtForceField force_field) {
	force_field_queue.push_back(force_field);
}

// Updates collision geometry
bool FlexSolver::update_meshes(NvFlexMapFlags wait) {
	NvFlexCollisionGeometry* geometry = (NvFlexCollisionGeometry*)NvFlexMap(buffers.geometry, wait);
	if (!geometry) return false;

	for (int i = 0; i < Min(meshes.size(), (size_t)MAX_COLLIDERS); i++) {
		FlexMesh mesh = meshes[i];
		geometry[i].triMesh.mesh = mesh.get_id();
		geometry[i].triMesh.scale[0] = 1;
		geometry[i].triMesh.scale[1] = 1;
		geometry[i].triMesh.scale[2] = 1;

		geometry[i].convexMesh.mesh = mesh.get_id();
		geometry[i].convexMesh.scale[0] = 1;
		geometry[i].convexMesh.scale[1] = 1;
		geometry[i].convexMesh.scale[2] = 1;
		
		hosts.geometry_flags[i] = mesh.get_flags();

		hosts.geometry_prevpos[i] = mesh.get_ppos();
		hosts.geometry_pos[i] = mesh.get_pos();

		hosts.geometry_prevang[i] = mesh.get_pang();
		hosts.geometry_ang[i] = mesh.get_ang();

		meshes[i].update();
	}
	NvFlexUnmap(buffers.geometry);

	return true;
}

// please do not ask me how this code works or what its doing. I honestly don't know. Don't touch it.
bool FlexSolver::tick(float dt, NvFlexMapFlags wait) {
	// Avoid ticking if the deltatime ends up being zero, as it invalidates the simulation
	dt *= get_parameter("timescale");
	if (dt > 0 && get_active_particles() > 0) {

		bool active_modified = false;

		// Invalidate (remove) particles with bad lifetimes (NOTE THAT A LIFETIME OF ZERO IS STILL AN INVALID LIFETIME)
		// we do this first, because it is relatively expensive (loop over every particle). mapping buffers waits for the GPU to finish calculations..
		// ..so we may as well not waste time waiting for that and do this beforehand
		// TODO: This could potentially be modified to work in a compute shader during FleX updates, this may be faster? (is this algorithm even parallelizable?)
		int min_particle_index, max_particle_index;
		min_particle_index = max_particle_index = hosts.particle_active[0];
		for (int i = 0; i < copy_active.elementCount; i++) {
			int particle_index = hosts.particle_active[i];
			min_particle_index = Min(min_particle_index, particle_index);
			max_particle_index = Max(max_particle_index, particle_index);

			float& particle_life = hosts.particle_lifetime[particle_index];
			particle_life -= dt;
			if (particle_life <= 0) {
				particle_queue_index = Min(particle_queue_index, particle_index);	// don't forget to update our minimum valid particle index!
				hosts.particle_active[i] = hosts.particle_active[--copy_active.elementCount];	// swap index 'i' and end index
				i--;	// we just shifted a particle that wont be iterated over, go back and check it
				active_modified = true;
			}
		}

		if (!update_meshes(wait)) return false;

		NvFlexCopyDesc copy = NvFlexCopyDesc();
		copy.dstOffset = min_particle_index;
		copy.srcOffset = min_particle_index;
		copy.elementCount = max_particle_index - min_particle_index + 1;

		// Add queued particles
		if (!particle_queue.empty()) {	
			// this is the intended way youre intended to add particles.
			
			// These aren't actually updated in the tick hook
			NvFlexGetParticles(solver, buffers.particle_pos, &copy);
			NvFlexGetVelocities(solver, buffers.particle_vel, &copy);

			hosts.particle_pos = (Vector4D*)NvFlexMap(buffers.particle_pos, eNvFlexMapWait);
			hosts.particle_vel = (Vector*)NvFlexMap(buffers.particle_vel, eNvFlexMapWait);
			for (const std::pair<int, Particle>& particle : particle_queue) {
				if (hosts.particle_lifetime[particle.first] > 0) {	// particle removed before being created (ie. between physics tick)
					set_particle(particle.first, copy_active.elementCount++, particle.second);

					// Don't forget to recalculate!
					min_particle_index = Min(min_particle_index, particle.first);
					max_particle_index = Max(max_particle_index, particle.first);
				}
			}
			NvFlexUnmap(buffers.particle_pos);
			NvFlexUnmap(buffers.particle_vel);
			
			copy.dstOffset = min_particle_index;
			copy.srcOffset = min_particle_index;
			copy.elementCount = max_particle_index - min_particle_index + 1;

			// Update particle information
			NvFlexSetParticles(solver, buffers.particle_pos, &copy);
			NvFlexSetVelocities(solver, buffers.particle_vel, &copy);

			// My "async" solution, which adds particles without needing to map a buffer
			// this works, but causes particle flickering, which I have yet to fix
			/*
			bool first = true;
			NvFlexCopyDesc copy = NvFlexCopyDesc();
			for (const std::pair<int, Particle>& particle : particle_queue) {
				// indices are split, set particles and reset copy description
				if (first) {
					copy.dstOffset = particle.first;
					first = false;
				} else {
					if (particle.first - copy.srcOffset > 1) {
						copy.srcOffset = copy.dstOffset;
						NvFlexSetParticles(solver, buffers.particle_pos, &copy);
						NvFlexSetVelocities(solver, buffers.particle_vel, &copy);
						copy.dstOffset = particle.first;
						copy.elementCount = 0;
					}
				}

				set_particle(particle.first, copy_active.elementCount++, particle.second);
				//hosts.particle_pos_buffer[particle.first] = particle.second.pos;
				//hosts.particle_vel_buffer[particle.first] = particle.second.vel;
				copy.elementCount++;
				copy.srcOffset = particle.first;
			}
			// there will always be excess
			copy.srcOffset = copy.dstOffset;
			NvFlexSetParticles(solver, buffers.particle_pos, &copy);
			NvFlexSetVelocities(solver, buffers.particle_vel, &copy);*/
			
			// finish
			NvFlexSetPhases(solver, buffers.particle_phase, &copy);
			particle_queue.clear();
			active_modified = true;
		}

		if (active_modified) {
			NvFlexSetActive(solver, buffers.particle_active, &copy_active);
			NvFlexSetActiveCount(solver, copy_active.elementCount);
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

		NvFlexSetParams(solver, &parameters);
		NvFlexExtSetForceFields(force_field_callback, force_field_queue.data(), force_field_queue.size());

		// tick
		NvFlexUpdateSolver(solver, dt, (int)get_parameter("substeps"), false);

		// read back (async)
		//NvFlexGetParticles(solver, buffers.particle_pos, NULL);		// what the fuck.
		//NvFlexGetVelocities(solver, buffers.particle_vel, NULL);		// ^
		NvFlexGetDiffuseParticles(solver, buffers.diffuse_pos, buffers.diffuse_vel, buffers.diffuse_count);

		if (get_active_triangles() > 0) {
			NvFlexGetNormals(solver, buffers.triangle_normals, &copy);
		}

		if (parameters.anisotropyScale != 0) {
			NvFlexGetAnisotropy(solver, buffers.particle_ani0, buffers.particle_ani1, buffers.particle_ani2, &copy);
		}

		if (parameters.smoothing != 0) {
			NvFlexGetSmoothParticles(solver, buffers.particle_smooth, &copy);
		}

		if (get_parameter("reaction_forces")) {
			NvFlexGetParticles(solver, buffers.particle_pos, &copy);
			NvFlexGetVelocities(solver, buffers.particle_vel, &copy);
			NvFlexGetContacts(solver, buffers.contact_planes, buffers.contact_vel, buffers.contact_indices, buffers.contact_count);
		}

		force_field_queue.clear();

		return true;
	} else {
		update_meshes(wait);
		force_field_queue.clear();

		return false;
	}
}

void FlexSolver::add_mesh(FlexMesh mesh) {
	meshes.push_back(mesh);
}

// TODO(?): Use a linked list instead of a vector
void FlexSolver::remove_mesh(int id) {
	for (int i = meshes.size() - 1; i >= 0; i--) {
		if (meshes[i].get_entity_id() == id) {
			// Free mesh buffers
			meshes[i].destroy();
			meshes.erase(meshes.begin() + i);
		}
	}
}

bool FlexSolver::set_parameter(std::string param, float number) {
	try {
		*param_map.at(param) = number;
		return true;
	}
	catch (std::exception e) {
		if (param == "iterations") {	// defined as an int instead of a float, so it needs to be seperate
			parameters.numIterations = (int)number;
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
			return (float)parameters.numIterations;
		}
		return NAN;
	}
}

// Initializes a box around a FleX solver with a mins and maxs
void FlexSolver::enable_bounds(Vector mins, Vector maxs) {

	// Right
	parameters.planes[0][0] = 1.f;
	parameters.planes[0][1] = 0.f;
	parameters.planes[0][2] = 0.f;
	parameters.planes[0][3] = -mins.x;

	// Left
	parameters.planes[1][0] = -1.f;
	parameters.planes[1][1] = 0.f;
	parameters.planes[1][2] = 0.f;
	parameters.planes[1][3] = maxs.x;

	// Forward
	parameters.planes[2][0] = 0.f;
	parameters.planes[2][1] = 1.f;
	parameters.planes[2][2] = 0.f;
	parameters.planes[2][3] = -mins.y;

	// Backward
	parameters.planes[3][0] = 0.f;
	parameters.planes[3][1] = -1.f;
	parameters.planes[3][2] = 0.f;
	parameters.planes[3][3] = maxs.y;

	// Bottom
	parameters.planes[4][0] = 0.f;
	parameters.planes[4][1] = 0.f;
	parameters.planes[4][2] = 1.f;
	parameters.planes[4][3] = -mins.z;

	// Top
	parameters.planes[5][0] = 0.f;
	parameters.planes[5][1] = 0.f;
	parameters.planes[5][2] = -1.f;
	parameters.planes[5][3] = maxs.z;

	parameters.numPlanes = 6;
}

void FlexSolver::disable_bounds() {
	parameters.numPlanes = 0;
}

// Initializes a solver in a FleX library
FlexSolver::FlexSolver(NvFlexLibrary* library, int particles) {
	if (library == nullptr) return;		// Panic

	NvFlexSetSolverDescDefaults(&solver_description);
	solver_description.maxParticles = particles;
	solver_description.maxDiffuseParticles = particles;

	this->library = library;
	solver = NvFlexCreateSolver(library, &solver_description);

	parameters.gravity[0] = 0.0f;
	parameters.gravity[1] = 0.0f;
	parameters.gravity[2] = -15.24f;	// Source gravity (600 inch^2) in m/s^2

	parameters.wind[0] = 0.0f;
	parameters.wind[1] = 0.0f;
	parameters.wind[2] = 0.0f;

	parameters.radius = 10.f;
	parameters.viscosity = 0.0f;
	parameters.dynamicFriction = 0.5f;
	parameters.staticFriction = 0.5f;
	parameters.particleFriction = 0.0f;
	parameters.freeSurfaceDrag = 0.0f;
	parameters.drag = 0.0f;
	parameters.lift = 0.0f;
	parameters.numIterations = 3;
	parameters.fluidRestDistance = 6.5f;
	parameters.solidRestDistance = 6.5f;

	parameters.anisotropyScale = 1.f;
	parameters.anisotropyMin = 0.1f;
	parameters.anisotropyMax = 0.5f;
	parameters.smoothing = 1.0f;

	parameters.dissipation = 0.f;
	parameters.damping = 0.0f;
	parameters.particleCollisionMargin = 0.f;
	parameters.shapeCollisionMargin = 0.f;	// Increase if lots of water pressure is expected. Higher values cause more collision clipping
	parameters.collisionDistance = 5.f; // Needed for tri-particle intersection
	parameters.sleepThreshold = 0.1f;
	parameters.shockPropagation = 0.0f;
	parameters.restitution = 0.0f;

	parameters.maxSpeed = 1e5;
	parameters.maxAcceleration = 1e4;
	parameters.relaxationMode = eNvFlexRelaxationLocal;
	parameters.relaxationFactor = 0.25f;	// only works with eNvFlexRelaxationGlobal
	parameters.solidPressure = 0.5f;
	parameters.adhesion = 0.0f;
	parameters.cohesion = 0.01f;
	parameters.surfaceTension = 0.000001f;
	parameters.vorticityConfinement = 0.0f;
	parameters.buoyancy = 1.0f;

	parameters.diffuseThreshold = 100.f;
	parameters.diffuseBuoyancy = 1.f;
	parameters.diffuseDrag = 0.8f;
	parameters.diffuseBallistic = 2;
	parameters.diffuseLifetime = 5.f;	// not actually in seconds

	parameters.numPlanes = 0;

	param_map["gravity"] = &(parameters.gravity[2]);
	param_map["radius"] = &parameters.radius;
	param_map["viscosity"] = &parameters.viscosity;
	param_map["dynamic_friction"] = &parameters.dynamicFriction;
	param_map["static_friction"] = &parameters.staticFriction;
	param_map["particle_friction"] = &parameters.particleFriction;
	param_map["free_surface_drag"] = &parameters.freeSurfaceDrag;
	param_map["drag"] = &parameters.drag;
	param_map["lift"] = &parameters.lift;
	//param_map["iterations"] = &params->numIterations;				// integer, cant map
	param_map["fluid_rest_distance"] = &parameters.fluidRestDistance;
	param_map["solid_rest_distance"] = &parameters.solidRestDistance;
	param_map["anisotropy_scale"] = &parameters.anisotropyScale;
	param_map["anisotropy_min"] = &parameters.anisotropyMin;
	param_map["anisotropy_max"] = &parameters.anisotropyMax;
	param_map["smoothing"] = &parameters.smoothing;
	param_map["dissipation"] = &parameters.dissipation;
	param_map["damping"] = &parameters.damping;
	param_map["particle_collision_margin"] = &parameters.particleCollisionMargin;
	param_map["shape_collision_margin"] = &parameters.shapeCollisionMargin;
	param_map["collision_distance"] = &parameters.collisionDistance;
	param_map["sleep_threshold"] = &parameters.sleepThreshold;
	param_map["shock_propagation"] = &parameters.shockPropagation;
	param_map["restitution"] = &parameters.restitution;
	param_map["max_speed"] = &parameters.maxSpeed;
	param_map["max_acceleration"] = &parameters.maxAcceleration;
	//param_map["relaxation_mode"] = &parameters.relaxationMode;		// ^
	param_map["relaxation_factor"] = &parameters.relaxationFactor;
	param_map["solid_pressure"] = &parameters.solidPressure;
	param_map["adhesion"] = &parameters.adhesion;
	param_map["cohesion"] = &parameters.cohesion;
	param_map["surface_tension"] = &parameters.surfaceTension;
	param_map["vorticity_confinement"] = &parameters.vorticityConfinement;
	param_map["buoyancy"] = &parameters.buoyancy;
	param_map["diffuse_threshold"] = &parameters.diffuseThreshold;
	param_map["diffuse_buoyancy"] = &parameters.diffuseBuoyancy;
	param_map["diffuse_drag"] = &parameters.diffuseDrag;
	//param_map["diffuse_ballistic"] = &parameters.diffuseBallistic;	// ^
	param_map["diffuse_lifetime"] = &parameters.diffuseLifetime;
	// Extra values we store which are not stored in flexes default parameters
	param_map["substeps"] = new float(3);
	param_map["timescale"] = new float(1);
	param_map["reaction_forces"] = new float(0);

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

	// This is the only exception buffer, as it is never sent to the GPU
	hosts.particle_lifetime = (float*)malloc(sizeof(float) * particles);

	force_field_callback = NvFlexExtCreateForceFieldCallback(solver);

	reset();
};

// Free memory
FlexSolver::~FlexSolver() {
	// Free props
	for (FlexMesh mesh : meshes) mesh.destroy();
	meshes.clear();

	delete param_map["substeps"];		// Seperate since its externally stored & not a default parameter
	delete param_map["timescale"];		// ^
	delete param_map["reaction_forces"];// ^

	NvFlexExtDestroyForceFieldCallback(force_field_callback);

	// Free buffers / hosts
	buffers.destroy();
	free((void*)hosts.particle_lifetime);

	NvFlexDestroySolver(solver);	// bye bye solver
	solver = nullptr;
}