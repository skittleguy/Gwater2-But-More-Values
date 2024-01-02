#pragma once
#include <NvFlex.h>
#include <map>
#include <vector>
#include <string>
#include "types.h"	// float3 & float4
#include "mesh.h"
#include <materialsystem/imesh.h>	// needed for imeshes

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
	std::map<std::string, float4*> hosts;
	std::vector<Mesh> meshes;

	void add_buffer(std::string name, int type, int count);
	NvFlexBuffer* get_buffer(std::string name);
	void default_parameters();
	void map_parameters(NvFlexParams* buffer);

public:
	std::vector<IMesh*> imeshes;		// This is mainly used in main.cpp since the FlexSolver class is specifically for data management

	void set_active_particles(int n);
	int get_active_particles();
	int get_max_particles();
	int get_max_contacts();

	// Returns a host (pointer of float4s) where FleX buffer data is transferred to. 
	// If the FleX buffer is never used, it may return NULL
	float4* get_host(std::string name);

	void add_particle(float4 pos, float3 vel, float4 col);
	bool pretick(NvFlexMapFlags wait);	// Handles transfer of FleX buffers to hosts & updates mesh positions/angles
	void tick(float dt);
	void add_mesh(Mesh mesh, NvFlexCollisionShapeType mesh_type, bool dynamic);
	void remove_mesh(int index);
	void update_mesh(int index, float3 new_pos, float3 new_ang);
	bool set_parameter(std::string param, float number);	// Returns true on success, false otherwise
	float get_parameter(std::string param);	// returns NaN on invalid parameter
	void enable_bounds(float3 mins, float3 maxs);
	void disable_bounds();

	FlexSolver(NvFlexLibrary* library, int particles);
	~FlexSolver();
};