#include "flex_renderer.h"
#include "cdll_client_int.h"	//IVEngineClient

extern IVEngineClient* engine = NULL;

//extern IMaterialSystem* materials = NULL;	// stops main branch compile from bitching

#define min(a, b) a < b ? a : b
#define max(a, b) a > b ? a : b

float u[3] = { 0.5 - SQRT3 / 2, 0.5, 0.5 + SQRT3 / 2 };
float v[3] = { 1, -0.5, 1 };

// Builds meshes of water particles with anisotropy
IMesh* _build_water_anisotropy(int id, FlexRendererThreadData data) {
	int start = id * MAX_PRIMATIVES;
	int end = min((id + 1) * MAX_PRIMATIVES, data.max_particles);

	// We need to figure out how many and which particles are going to be rendered
	int particles_to_render = end - start;	// Frustrum culling disabled for now, as mesh generation wont have a cam context
	/*
	for (int particle_index = start; particle_index < end; ++particle_index) {
		Vector particle_pos = data.particle_positions[particle_index].AsVector3D();

		// Frustrum culling
		Vector4D dst;
		Vector4DMultiply(data.view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
		//if (dst.z < 0 || -dst.x - dst.w > data.radius || dst.x - dst.w > data.radius || -dst.y - dst.w > data.radius || dst.y - dst.w > data.radius) continue;

		// PVS Culling
		//if (!engine->IsBoxVisible(particle_pos, particle_pos)) continue;
		
		// Particle is good, render it
		data.render_buffer[start + particles_to_render] = particle_index;
		particles_to_render++;
	}

	// Don't even bother
	if (particles_to_render == 0) return nullptr;*/

	IMesh* mesh = materials->GetRenderContext()->CreateStaticMesh(VERTEX_GWATER2, "");
	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, particles_to_render);
	for (int i = start; i < start + particles_to_render; ++i) {
		Vector4D particle_pos = data.particle_positions[i];
		Vector4D ani0 = data.particle_ani0 ? data.particle_ani0[i] : Vector4D(0, 0, 0, 0);
		Vector4D ani1 = data.particle_ani1 ? data.particle_ani1[i] : Vector4D(0, 0, 0, 0);
		Vector4D ani2 = data.particle_ani2 ? data.particle_ani2[i] : Vector4D(0, 0, 0, 0);

		for (int i = 0; i < 3; i++) {
			mesh_builder.TexCoord2f(0, u[i], v[i]);
			mesh_builder.TexCoord4f(1, ani0.x, ani0.y, ani0.z, ani0.w);	// shove anisotropy in 
			mesh_builder.TexCoord4f(2, ani1.x, ani1.y, ani1.z, ani1.w);
			mesh_builder.TexCoord4f(3, ani2.x, ani2.y, ani2.z, ani2.w);
			mesh_builder.Position3f(particle_pos.x, particle_pos.y, particle_pos.z);
			//mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
			mesh_builder.AdvanceVertex();
		}
	}
	mesh_builder.End();

	return mesh;
}

// Builds meshes of diffuse particles (scaled by velocity, buffer shoved inside ani0)
IMesh* _build_diffuse(int id, FlexRendererThreadData data) {
	int start = id * MAX_PRIMATIVES;
	int end = min((id + 1) * MAX_PRIMATIVES, data.max_particles);

	IMesh* mesh = materials->GetRenderContext()->CreateStaticMesh(VERTEX_GWATER2, "");
	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, end - start);
	for (int i = start; i < end; ++i) {
		Vector4D particle_pos = data.particle_positions[i];
		Vector4D ani0 = data.particle_ani0[i];
		float scalar = data.radius * particle_pos.w;

		for (int i = 0; i < 3; i++) {
			mesh_builder.TexCoord2f(0, u[i], v[i]);
			mesh_builder.TexCoord4f(1, ani0.x, ani0.y, ani0.z, scalar);
			mesh_builder.Position3f(particle_pos.x, particle_pos.y, particle_pos.z);
			mesh_builder.AdvanceVertex();
		}
	}
	mesh_builder.End();

	return mesh;
}

// lord have mercy brothers

// Launches 1 thread for each mesh. particles are split into meshes with MAX_PRIMATIVES number of primatives
void FlexRenderer::build_meshes(FlexSolver* flex, float diffuse_radius) {
	update_meshes();
	// Clear previous imeshes since they are being rebuilt
	//destroy_meshes();

	int max_particles = flex->get_active_particles();
	if (max_particles == 0) return;

	// View matrix, used in frustrum culling
	IMatRenderContext* render_context = materials->GetRenderContext();
	//VMatrix view_matrix, projection_matrix, view_projection_matrix;
	//render_context->GetMatrix(MATERIAL_VIEW, &view_matrix);
	//render_context->GetMatrix(MATERIAL_PROJECTION, &projection_matrix);
	//MatrixMultiply(projection_matrix, view_matrix, view_projection_matrix);

	// thread data
	FlexRendererThreadData water_data;
	//data.view_projection_matrix = view_projection_matrix;
	water_data.particle_positions = flex->get_parameter("smoothing") != 0 ? (Vector4D*)flex->get_host("particle_smooth") : (Vector4D*)flex->get_host("particle_pos");
	water_data.max_particles = max_particles;
	water_data.radius = flex->get_parameter("radius");
	//data.render_buffer = water_buffer;
	if (flex->get_parameter("anisotropy_scale") != 0) {		// Should we do anisotropy calculations?
		water_data.particle_ani0 = (Vector4D*)flex->get_host("particle_ani0");
		water_data.particle_ani1 = (Vector4D*)flex->get_host("particle_ani1");
		water_data.particle_ani2 = (Vector4D*)flex->get_host("particle_ani2");
	} else {
		water_data.particle_ani0 = nullptr;
		water_data.particle_ani1 = nullptr;
		water_data.particle_ani2 = nullptr;
	}

	int max_meshes = min(ceil(max_particles / (float)MAX_PRIMATIVES), allocated);
	for (int mesh_index = 0; mesh_index < max_meshes; mesh_index++) {
		// Launch thread
		queue[mesh_index] = threads->enqueue(_build_water_anisotropy, mesh_index, water_data);
	}

	// Remove meshes which wont be built
	for (int mesh = max_meshes; mesh < allocated; mesh++) {
		if (meshes[mesh] == nullptr) continue;

		render_context->DestroyStaticMesh(meshes[mesh]);
		meshes[mesh] = nullptr;
	}
	
	/// Diffuse particles ///

	max_particles = flex->get_active_diffuse();
	if (max_particles == 0) return;
	
	// update thread data
	FlexRendererThreadData diffuse_data;
	diffuse_data.particle_positions = (Vector4D*)flex->get_host("diffuse_pos");;
	diffuse_data.max_particles = max_particles;
	diffuse_data.radius = flex->get_parameter("radius") / flex->get_parameter("diffuse_lifetime") * diffuse_radius;
	diffuse_data.particle_ani0 = (Vector4D*)flex->get_host("diffuse_vel");

	max_meshes = min(ceil(max_particles / (float)MAX_PRIMATIVES), allocated);
	for (int mesh_index = 0; mesh_index < max_meshes; mesh_index++) {
		queue[mesh_index + allocated] = threads->enqueue(_build_diffuse, mesh_index, diffuse_data);
	}

	// Remove meshes which wont be built
	for (int mesh = max_meshes + allocated; mesh < allocated * 2; mesh++) {
		if (meshes[mesh] == nullptr) continue;

		render_context->DestroyStaticMesh(meshes[mesh]);
		meshes[mesh] = nullptr;
	}
};

void FlexRenderer::update_meshes() {
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh = 0; mesh < allocated * 2; mesh++) {
		if (queue[mesh].valid()) {
			if (meshes[mesh] != nullptr) render_context->DestroyStaticMesh(meshes[mesh]);
			meshes[mesh] = queue[mesh].get();
		}
	}
}

void FlexRenderer::draw_water() {
	//update_meshes();	// Update status of water meshes (join threads)

	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh = 0; mesh < allocated; mesh++) {
		if (meshes[mesh] == nullptr) continue;

		meshes[mesh]->Draw();
	}
};

void FlexRenderer::draw_diffuse() {
	//update_meshes();

	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh = allocated; mesh < allocated * 2; mesh++) {
		if (meshes[mesh] == nullptr) continue;

		meshes[mesh]->Draw();
	}
};

void FlexRenderer::destroy_meshes() {
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh = 0; mesh < allocated * 2; mesh++) {
		if (meshes[mesh] == nullptr) continue;

		render_context->DestroyStaticMesh(meshes[mesh]);
		meshes[mesh] = nullptr;
	}
}

// Allocate buffers
FlexRenderer::FlexRenderer(int max_meshes) {
	allocated = max_meshes;

	// Water meshes take (0 to allocated), diffuse take (allocated to allocated * 2)
	meshes = (IMesh**)calloc(sizeof(IMesh*), allocated * 2);
	if (!meshes) return;	// TODO: Fix undefined behavior if this statement runs

	threads = new ThreadPool(MAX_THREADS);

	queue = (std::future<IMesh*>*)calloc(sizeof(std::future<IMesh*>), allocated * 2);	// Needs to be zero initialized
	if (!queue) return;

	/*water_buffer = (int*)malloc(sizeof(int) * allocated * MAX_PRIMATIVES);
	if (!water_buffer) return;

	diffuse_buffer = (int*)malloc(sizeof(int) * allocated * MAX_PRIMATIVES);
	if (!diffuse_buffer) return;*/
};

FlexRenderer::~FlexRenderer() {
	if (meshes == nullptr) return;	// Never allocated (out of ram?)

	//if (materials->GetRenderContext() == nullptr) return;	// wtf?
	// Destroy existing meshes
	destroy_meshes();
	
	// Redestroy water that was being built in threads
	update_meshes();
	destroy_meshes();

	delete threads;

	//if (water_buffer != nullptr) free(water_buffer);
	//if (diffuse_buffer != nullptr) free(diffuse_buffer);
	if (meshes != nullptr) free(meshes);
	if (queue != nullptr) free(queue);
};