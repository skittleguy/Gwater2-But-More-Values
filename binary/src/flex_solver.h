#pragma once
#include <NvFlex.h>
#include <NvFlexExt.h>
#include <map>
#include <vector>
#include <string>
#include "flex_mesh.h"

enum FlexPhase {
	WATER = (0 & eNvFlexPhaseGroupMask) | ((eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid) & eNvFlexPhaseFlagsMask) | (eNvFlexPhaseShapeChannelMask & eNvFlexPhaseShapeChannelMask),
	CLOTH = (0 & eNvFlexPhaseGroupMask) | ((eNvFlexPhaseSelfCollide					   ) & eNvFlexPhaseFlagsMask) | (eNvFlexPhaseShapeChannelMask & eNvFlexPhaseShapeChannelMask),
};

struct Particle {
	Vector4D pos = Vector4D(0, 0, 0, 1);
	Vector vel = Vector(0, 0, 0);
	int phase = 0;
};

// Struct that holds FleX solver data
class FlexSolver {
private:
	NvFlexLibrary* library = nullptr;
	NvFlexSolver* solver = nullptr;
	NvFlexParams* params = nullptr;
	NvFlexExtForceFieldCallback* force_field_callback = nullptr;	// unsure why this is required. crashes without it
	NvFlexCopyDesc copy_active = NvFlexCopyDesc();
	NvFlexCopyDesc copy_particles = NvFlexCopyDesc();
	NvFlexCopyDesc copy_triangles = NvFlexCopyDesc();
	NvFlexCopyDesc copy_springs = NvFlexCopyDesc();
	NvFlexSolverDesc solver_description = NvFlexSolverDesc();	// stores stuff such as max particles
	std::map<std::string, NvFlexBuffer*> buffers;
	std::map<std::string, float*> param_map; // TODO: figure out if this is the best way to do this... Would a set/get switch statement be better..?
	std::map<std::string, void*> hosts;
	std::vector<FlexMesh> meshes;		// physics meshes.. not visual!
	std::vector<Particle> particle_queue;	// Doesnt actually hold particles. Just a queue
	std::vector<NvFlexExtForceField> force_field_queue;
	
	void add_buffer(std::string name, int type, int count);
	//NvFlexBuffer* get_buffer(std::string name);

public:
	void reset();
	int get_active_particles();
	int get_active_diffuse();
	int get_active_triangles();
	int get_max_particles();
	int get_max_diffuse_particles();
	int get_max_contacts();
	std::vector<FlexMesh>* get_meshes();

	inline NvFlexBuffer* get_buffer(std::string name);
	inline void* get_host(std::string name);	// Returns a host (pointer of float4s) where FleX buffer data is transferred to. 

	void add_particle(Particle particle);
	void add_cloth(Particle particle, Vector2D size);
	void set_particle(int index, Particle particle);
	void add_force_field(NvFlexExtForceField force_field);
	
	bool tick(float dt, NvFlexMapFlags wait);

	void add_mesh(FlexMesh mesh);
	void remove_mesh(int id);
	void update_mesh(int id, Vector new_pos, QAngle new_ang);

	bool set_parameter(std::string param, float number);	// Returns true on success, false otherwise
	float get_parameter(std::string param);	// returns NaN on invalid parameter
	void enable_bounds(Vector mins, Vector maxs);
	void disable_bounds();

	FlexSolver(NvFlexLibrary* library, int particles);
	~FlexSolver();
};