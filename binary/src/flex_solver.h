#pragma once
#include <NvFlex.h>
#include <map>
#include <vector>
#include <string>
#include "mesh.h"

// Struct that holds FleX solver data
class FlexSolver {
private:
	NvFlexLibrary* library = nullptr;	
	NvFlexSolver* solver = nullptr;
	NvFlexParams* params = nullptr;
	NvFlexCopyDesc* copy_description = new NvFlexCopyDesc();
	NvFlexSolverDesc solver_description = NvFlexSolverDesc();
	std::map<std::string, NvFlexBuffer*> buffers;
	std::map<std::string, float*> param_map;
	std::map<std::string, void*> hosts;
	std::vector<Mesh*> meshes;	// physmeshes

	void add_buffer(std::string name, int type, int count);
	NvFlexBuffer* get_buffer(std::string name);

public:
	void set_active_particles(int n);
	int get_active_particles();
	int get_max_particles();
	int get_max_contacts();

	// Returns a host (pointer of float4s) where FleX buffer data is transferred to. 
	void* get_host(std::string name);

	void add_particle(Vector4D pos, Vector vel);
	void add_callback(NvFlexSolverCallback callback, NvFlexSolverCallbackStage stage);
	bool pretick(NvFlexMapFlags wait);	// Updates mesh positions/angles & particle queues
	void tick(float dt);
	void add_mesh(Mesh* mesh, NvFlexCollisionShapeType mesh_type, bool dynamic);
	void remove_mesh(int index);
	void update_mesh(int index, Vector new_pos, QAngle new_ang);
	bool set_parameter(std::string param, float number);	// Returns true on success, false otherwise
	float get_parameter(std::string param);	// returns NaN on invalid parameter
	void enable_bounds(Vector mins, Vector maxs);
	void disable_bounds();

	FlexSolver(NvFlexLibrary* library, int particles);
	~FlexSolver();
};