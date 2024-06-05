#pragma once
#include <NvFlex.h>
#include <map>
#include <vector>
#include <string>
#include "flex_mesh.h"

struct Particle {
	Vector4D pos = Vector4D(0, 0, 0, 1);
	Vector vel = Vector(0, 0, 0);
};

// Struct that holds FleX solver data
class FlexSolver {
private:
	NvFlexLibrary* library = nullptr;
	NvFlexSolver* solver = nullptr;
	NvFlexParams* params = nullptr;
	NvFlexCopyDesc* copy_description = new NvFlexCopyDesc();
	NvFlexSolverDesc solver_description = NvFlexSolverDesc();	// stores stuff such as max particles
	std::map<std::string, NvFlexBuffer*> buffers;
	std::map<std::string, float*> param_map; // TODO: figure out if this is the best way to do this... Would a set/get switch statement be better..?
	std::map<std::string, void*> hosts;
	std::vector<FlexMesh> meshes;		// physics meshes.. not visual!
	std::vector<Particle> particles;	// Doesnt actually hold particles. Just a queue

	void add_buffer(std::string name, int type, int count);
	//NvFlexBuffer* get_buffer(std::string name);

public:
	void set_active_particles(int n);
	void set_active_diffuse(int n);
	int get_active_particles();
	int get_active_diffuse();
	int get_max_particles();
	int get_max_diffuse_particles();
	int get_max_contacts();
	std::vector<FlexMesh>* get_meshes();

	inline NvFlexBuffer* get_buffer(std::string name);
	void* get_host(std::string name);	// Returns a host (pointer of float4s) where FleX buffer data is transferred to. 

	void add_particle(Vector4D pos, Vector vel);
	
	bool pretick(NvFlexMapFlags wait);	// Updates mesh positions/angles & particle queues
	void tick(float dt);

	void add_mesh(FlexMesh mesh);
	void remove_mesh(int id);
	void update_mesh(int id, Vector new_pos, QAngle new_ang);

	bool set_parameter(std::string param, float number);	// Returns true on success, false otherwise
	float get_parameter(std::string param);	// returns NaN on invalid parameter
	void enable_bounds(Vector mins, Vector maxs);
	void disable_bounds();


	void map_particles();

	FlexSolver(NvFlexLibrary* library, int particles);
	~FlexSolver();
};