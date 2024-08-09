#pragma once
#include <NvFlex.h>
#include <NvFlexExt.h>
#include <map>
#include <vector>
#include <string>
#include "flex_mesh.h"

#define MAX_COLLIDERS 8192	// source can't go over this number of props so.. might as well just have it as the limit

enum FlexPhase {
	WATER = (0 & eNvFlexPhaseGroupMask) | ((eNvFlexPhaseSelfCollide | eNvFlexPhaseFluid) & eNvFlexPhaseFlagsMask) | (eNvFlexPhaseShapeChannelMask & eNvFlexPhaseShapeChannelMask),
	CLOTH = (0 & eNvFlexPhaseGroupMask) | ((eNvFlexPhaseSelfCollide					   ) & eNvFlexPhaseFlagsMask) | (eNvFlexPhaseShapeChannelMask & eNvFlexPhaseShapeChannelMask),
};

struct Particle {
	Vector4D pos = Vector4D(0, 0, 0, 1);
	Vector vel = Vector(0, 0, 0);
	int phase = FlexPhase::WATER;
	float lifetime = FLT_MAX;
};

// Holds flex buffer information
// TODO(?): Should this be defined as an std::pair, so the host and FleX buffers are always together?
struct FlexBuffers {
	NvFlexBuffer* particle_pos;
	NvFlexBuffer* particle_vel;
	NvFlexBuffer* particle_phase;
	NvFlexBuffer* particle_active;
	NvFlexBuffer* particle_smooth;
	
	NvFlexBuffer* particle_ani0;
	NvFlexBuffer* particle_ani1;
	NvFlexBuffer* particle_ani2;

	NvFlexBuffer* geometry;
	NvFlexBuffer* geometry_pos;
	NvFlexBuffer* geometry_prevpos;
	NvFlexBuffer* geometry_quat;
	NvFlexBuffer* geometry_prevquat;
	NvFlexBuffer* geometry_flags;

	NvFlexBuffer* contact_planes;
	NvFlexBuffer* contact_vel;
	NvFlexBuffer* contact_count;
	NvFlexBuffer* contact_indices;

	NvFlexBuffer* diffuse_pos;
	NvFlexBuffer* diffuse_vel;
	NvFlexBuffer* diffuse_count;

	NvFlexBuffer* triangle_indices;
	NvFlexBuffer* triangle_normals;

	NvFlexBuffer* spring_indices;
	NvFlexBuffer* spring_restlengths;
	NvFlexBuffer* spring_stiffness;

	std::vector<NvFlexBuffer*> buffers;

	template <typename T> NvFlexBuffer* init(NvFlexLibrary* library, T** host, int count);
	void destroy();
};

// Holds CPU mapped NvFlexBuffer* data
struct FlexHosts {
	Vector4D* particle_pos;
	Vector* particle_vel;
	int* particle_phase;
	int* particle_active;
	Vector4D* particle_smooth;
	float* particle_lifetime;

	Vector4D* particle_ani0;
	Vector4D* particle_ani1;
	Vector4D* particle_ani2;

	NvFlexCollisionGeometry* geometry;
	Vector4D* geometry_pos;
	Vector4D* geometry_prevpos;
	Vector4D* geometry_ang;
	Vector4D* geometry_prevang;
	int* geometry_flags;

	Vector4D* contact_planes;
	Vector4D* contact_vel;
	int* contact_count;
	int* contact_indices;

	Vector4D* diffuse_pos;
	Vector4D* diffuse_vel;
	int* diffuse_count;

	int* triangle_indices;
	Vector4D* triangle_normals;

	int* spring_indices;
	float* spring_restlengths;
	float* spring_stiffness;
};

// Struct that holds FleX solver data
class FlexSolver {
private:
	NvFlexLibrary* library = nullptr;
	NvFlexSolver* solver = nullptr;
	NvFlexExtForceFieldCallback* force_field_callback = nullptr;	// unsure why this is required. crashes without it
	NvFlexParams parameters = NvFlexParams();
	NvFlexCopyDesc copy_active = NvFlexCopyDesc();
	NvFlexCopyDesc copy_triangles = NvFlexCopyDesc();
	NvFlexCopyDesc copy_springs = NvFlexCopyDesc();
	NvFlexSolverDesc solver_description = NvFlexSolverDesc();	// stores stuff such as max particles
	std::map<std::string, float*> param_map; // TODO: figure out if this is the best way to do this... Would a set/get switch statement be better..?
	std::vector<FlexMesh> meshes;		// physics meshes.. not visual!
	std::vector<Particle> particle_queue;
	std::vector<NvFlexExtForceField> force_field_queue;

	void set_particle(int particle_index, int active_index, Particle particle);

public:
	FlexBuffers buffers;
	FlexHosts hosts;

	void reset();
	void reset_cloth();
	int get_active_particles();
	int get_active_diffuse();
	int get_active_triangles();
	int get_max_particles();
	int get_max_diffuse_particles();
	int get_max_contacts();
	std::vector<FlexMesh>* get_meshes();

	void add_particle(Particle particle);
	void add_cloth(Particle particle, Vector2D size);
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