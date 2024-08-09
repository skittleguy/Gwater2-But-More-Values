#include "flex_renderer.h"
#include "cdll_client_int.h"	//IVEngineClient

extern IVEngineClient* engine = NULL;

//extern IMaterialSystem* materials = NULL;	// stops main branch compile from bitching

#define min(a, b) a < b ? a : b

// lord have mercy brothers

float water_u[3] = { 0.5 - SQRT3 / 2, 0.5, 0.5 + SQRT3 / 2 };
float water_v[3] = { 1, -0.5, 1 };

// Builds meshes of water particles with anisotropy
IMesh* _build_water_anisotropy(int id, FlexRendererThreadData data) {
	int start = id * MAX_PRIMATIVES;
	int end = min((id + 1) * MAX_PRIMATIVES, data.max_particles);

	// We need to figure out how many and which particles are going to be rendered
	int particle_indices[MAX_PRIMATIVES];
	int particles_to_render = 0;	// Frustrum culling disabled for now, as mesh generation wont have a cam context
	for (int i = start; i < end; ++i) {
		int particle_index = data.particle_active[i];
		if (data.particle_phases[particle_index] != FlexPhase::WATER) continue;	// not water, bail

		Vector particle_pos = data.particle_positions[particle_index].AsVector3D();

		// Frustrum culling
		Vector4D dst;
		Vector4DMultiply(data.view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
		if (dst.z < data.radius || -dst.x - dst.w > data.radius || dst.x - dst.w > data.radius || -dst.y - dst.w > data.radius || dst.y - dst.w > data.radius) continue;

		// PVS Culling
		if (!engine->IsBoxVisible(particle_pos, particle_pos)) continue;
		
		// Particle is good, render it
		particle_indices[particles_to_render] = particle_index;
		particles_to_render++;
	}

	// Don't even bother
	if (particles_to_render == 0) return nullptr;

	// mesh data is valid, start building our mesh
	IMesh* mesh = materials->GetRenderContext()->CreateStaticMesh(VERTEX_GWATER2, "");
	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, particles_to_render);
	for (int mesh_index = start; mesh_index < start + particles_to_render; ++mesh_index) {
		int particle_index = particle_indices[mesh_index - start];
		Vector particle_pos = data.particle_positions[particle_index].AsVector3D();
		Vector4D ani0 = data.particle_ani0 ? data.particle_ani0[particle_index] : Vector4D(0, 0, 0, 0);
		Vector4D ani1 = data.particle_ani1 ? data.particle_ani1[particle_index] : Vector4D(0, 0, 0, 0);
		Vector4D ani2 = data.particle_ani2 ? data.particle_ani2[particle_index] : Vector4D(0, 0, 0, 0);

		// bias the shit out of the anisotropy calculations
		// makes it look "better" as we're doing vertex transforms instead of ellipsoid raytracing. not accurate at all
		float scale_mult = (5.f / data.radius);

		// manual transform
		ani0.x *= scale_mult * ani0.w; ani0.y *= scale_mult * ani0.w; ani0.z *= scale_mult * ani0.w;
		ani1.x *= scale_mult * ani1.w; ani1.y *= scale_mult * ani1.w; ani1.z *= scale_mult * ani1.w;
		ani2.x *= scale_mult * ani2.w; ani2.y *= scale_mult * ani2.w; ani2.z *= scale_mult * ani2.w;

		// extract normal / right and up (to rotate sprite toward player)
		Vector forward = (particle_pos - data.eye_pos).Normalized();
		Vector right = (forward.Cross(Vector(0, 0, 1))).Normalized();
		Vector up = forward.Cross(right);

		for (int i = 0; i < 3; i++) {	
			Vector local_pos = (right * (water_u[i] - 0.5) + up * (water_v[i] - 0.5)) * data.radius * 0.2;

			// Anisotropy warping
			float dot0 = local_pos.Dot(ani0.AsVector3D());
			float dot1 = local_pos.Dot(ani1.AsVector3D());
			float dot2 = local_pos.Dot(ani2.AsVector3D());
			local_pos += (ani0.AsVector3D() * dot0 + ani1.AsVector3D() * dot1 + ani2.AsVector3D() * dot2);

			mesh_builder.TexCoord2f(0, water_u[i], water_v[i]);
			mesh_builder.Position3f(particle_pos.x + local_pos.x, particle_pos.y + local_pos.y, particle_pos.z + local_pos.z);
			mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
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

	// We need to figure out how many and which particles are going to be rendered
	int particle_indices[MAX_PRIMATIVES];
	int particles_to_render = 0;	// Frustrum culling disabled for now, as mesh generation wont have a cam context
	for (int particle_index = start; particle_index < end; ++particle_index) {
		Vector particle_pos = data.particle_positions[particle_index].AsVector3D();

		// Frustrum culling
		Vector4D dst;
		Vector4DMultiply(data.view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
		if (dst.z < 0 || -dst.x - dst.w > 0 || dst.x - dst.w > 0 || -dst.y - dst.w > 0 || dst.y - dst.w > 0) continue;

		// PVS Culling
		if (!engine->IsBoxVisible(particle_pos, particle_pos)) continue;

		// Particle is good, render it
		particle_indices[particles_to_render] = particle_index;
		particles_to_render++;
	}

	// Don't even bother
	if (particles_to_render == 0) return nullptr;

	// mesh data is valid, start building our mesh
	IMesh* mesh = materials->GetRenderContext()->CreateStaticMesh(VERTEX_GWATER2, "");
	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, particles_to_render);
	for (int mesh_index = start; mesh_index < start + particles_to_render; ++mesh_index) {
		int particle_index = particle_indices[mesh_index - start];
		Vector4D particle_pos = data.particle_positions[particle_index];

		// warp diffuse based on velocity
		Vector ani0 = data.particle_ani0[particle_index].AsVector3D() * 0.03;
		float scalar = data.radius * particle_pos.w;
		if (ani0.Dot(ani0) > 2 * 2) ani0 = ani0.Normalized() * 2;	// 2 = max stretch (hardcoded)

		// extract normal / right and up (to rotate sprite toward player)
		Vector forward = (particle_pos.AsVector3D() - data.eye_pos).Normalized();
		Vector right = (forward.Cross(Vector(0, 0, 1))).Normalized();
		Vector up = forward.Cross(right);

		for (int i = 0; i < 3; i++) {	
			Vector local_pos = (right * (water_u[i] - 0.5) + up * (water_v[i] - 0.5)) * scalar;

			// Anisotropy warping
			local_pos += ani0 * local_pos.Dot(ani0);

			mesh_builder.TexCoord2f(0, water_u[i], water_v[i]);
			mesh_builder.Position3f(particle_pos.x + local_pos.x, particle_pos.y + local_pos.y, particle_pos.z + local_pos.z);
			//mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
			mesh_builder.AdvanceVertex();
		}
	}
	mesh_builder.End();

	return mesh;
}

// Builds meshes of cloth, indices shoved in phase buffer, normals shoved in ani0
float cloth_u[6] = {0, 0, 1, 1, 0, 1};
float cloth_v[6] = {1, 0, 1, 1, 0, 0};
IMesh* _build_cloth(int id, FlexRendererThreadData data) {
	int start = id * MAX_PRIMATIVES;
	int end = min((id + 1) * MAX_PRIMATIVES, data.max_particles);

	// start building our mesh
	IMesh* mesh = materials->GetRenderContext()->CreateStaticMesh(MATERIAL_VERTEX_FORMAT_MODEL, "");
	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, end - start);
	for (int mesh_index = start; mesh_index < end; ++mesh_index) {
		for (int i = 0; i < 3; i++) {
			int particle_index = data.particle_phases[data.particle_active[mesh_index * 3 + i]];
			Vector particle_pos = data.particle_positions[particle_index].AsVector3D();
			Vector particle_normal = -data.particle_ani0[particle_index].AsVector3D();	// flex generates different triangle winding data, so normals must be inverted
			float userdata[4] = {0, 0, 0, 0};

			if (mesh_index % 2 == 0) {// fuck me
				mesh_builder.TexCoord2f(0, cloth_u[i], cloth_v[i]);
			} else {
				mesh_builder.TexCoord2f(0, cloth_u[i + 3], cloth_v[i + 3]);
			}
			mesh_builder.Position3f(particle_pos.x, particle_pos.y, particle_pos.z);
			mesh_builder.Normal3f(particle_normal.x, particle_normal.y, particle_normal.z);
			mesh_builder.UserData(userdata);
			mesh_builder.Color4f(1, 1, 1, 1);
			mesh_builder.AdvanceVertex();
		}
	}
	mesh_builder.End();

	return mesh;
}

// Launches 1 thread for each mesh. particles are split into meshes with MAX_PRIMATIVES number of primatives
void FlexRenderer::build_meshes(FlexSolver* flex, float diffuse_radius) {
	// Clear previous imeshes since they are being rebuilt
	destroy_meshes();
	//update_water();
	//update_cloth();
	//update_diffuse();

	int active_particles = flex->get_active_particles();
	if (active_particles == 0) return;

	CMatRenderContextPtr render_context(materials);

	// Get eye position for sprite calculations
	Vector eye_pos; render_context->GetWorldSpaceCameraPosition(&eye_pos);

	// View matrix, used in frustrum culling
	VMatrix view_matrix, projection_matrix, view_projection_matrix;
	render_context->GetMatrix(MATERIAL_VIEW, &view_matrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projection_matrix);
	MatrixMultiply(projection_matrix, view_matrix, view_projection_matrix);

	///// Water particles /////
	FlexRendererThreadData water_data;
	water_data.view_projection_matrix = view_projection_matrix;
	water_data.particle_positions = flex->get_parameter("smoothing") != 0 ? flex->hosts.particle_smooth : (Vector4D*)flex->hosts.particle_pos;
	water_data.particle_phases = flex->hosts.particle_phase;
	water_data.particle_active = flex->hosts.particle_active;
	water_data.max_particles = active_particles;
	water_data.radius = flex->get_parameter("radius");
	water_data.eye_pos = eye_pos;
	if (flex->get_parameter("anisotropy_scale") != 0) {		// Should we do anisotropy calculations?
		water_data.particle_ani0 = flex->hosts.particle_ani0;
		water_data.particle_ani1 = flex->hosts.particle_ani1;
		water_data.particle_ani2 = flex->hosts.particle_ani2;
	} else {
		water_data.particle_ani0 = nullptr;
		water_data.particle_ani1 = nullptr;
		water_data.particle_ani2 = nullptr;
	}

	for (int mesh_index = 0; mesh_index < ceil(active_particles / (float)MAX_PRIMATIVES); mesh_index++) {
		// Launch thread
		water_queue.push_back(threads->enqueue(_build_water_anisotropy, mesh_index, water_data));
	}
	
	///// Diffuse particles /////
	int active_diffuse = flex->get_active_diffuse();
	if (active_diffuse > 0) {
		// update thread data
		FlexRendererThreadData diffuse_data;
		diffuse_data.eye_pos = eye_pos;
		diffuse_data.view_projection_matrix = view_projection_matrix;
		diffuse_data.particle_positions = flex->hosts.diffuse_pos;
		diffuse_data.max_particles = active_diffuse;
		diffuse_data.radius = flex->get_parameter("radius") / flex->get_parameter("diffuse_lifetime") * diffuse_radius;
		diffuse_data.particle_ani0 = flex->hosts.diffuse_vel;

		for (int mesh_index = 0; mesh_index < ceil(active_diffuse / (float)MAX_PRIMATIVES); mesh_index++) {
			diffuse_queue.push_back(threads->enqueue(_build_diffuse, mesh_index, diffuse_data));
		}
	}

	///// Cloth /////
	int active_triangles = flex->get_active_triangles();
	if (active_triangles > 0) {
		// update thread data
		FlexRendererThreadData cloth_data;
		cloth_data.particle_positions = flex->hosts.particle_pos;
		cloth_data.max_particles = active_triangles;
		cloth_data.particle_ani0 = flex->hosts.triangle_normals;
		cloth_data.particle_phases = flex->hosts.triangle_indices;
		cloth_data.particle_active = flex->hosts.particle_active;

		for (int mesh_index = 0; mesh_index < ceil(active_triangles / (float)MAX_PRIMATIVES); mesh_index++) {
			triangle_queue.push_back(threads->enqueue(_build_cloth, mesh_index, cloth_data));
		}
	}
};

// Waits for all threads to finish and forces them to empty data. invalid data is not added
void FlexRenderer::update_water() {
	for (std::future<IMesh*>& mesh : water_queue) {
		IMesh* imesh = mesh.get();
		if (imesh != nullptr) water_meshes.push_back(imesh);
	}
	water_queue.clear();
}

// ^
void FlexRenderer::update_diffuse() {
	for (std::future<IMesh*>& mesh : diffuse_queue) {
		IMesh* imesh = mesh.get();
		if (imesh != nullptr) diffuse_meshes.push_back(imesh);
	}
	diffuse_queue.clear();
}

// ^
void FlexRenderer::update_cloth() {
	for (std::future<IMesh*>& mesh : triangle_queue) {
		IMesh* imesh = mesh.get();
		if (imesh != nullptr) triangle_meshes.push_back(imesh);
	}
	triangle_queue.clear();
}

// Renders water meshes
void FlexRenderer::draw_water() {
	update_water();

	for (IMesh* mesh : water_meshes) mesh->Draw();
};

void FlexRenderer::draw_diffuse() {
	update_diffuse();

	for (IMesh* mesh : diffuse_meshes) mesh->Draw();
};

void FlexRenderer::draw_cloth() {
	update_cloth();

	for (IMesh* mesh : triangle_meshes) mesh->Draw();
};

void FlexRenderer::destroy_meshes() {
	CMatRenderContextPtr render_context(materials);
	for (IMesh* mesh : water_meshes) render_context->DestroyStaticMesh(mesh);
	water_meshes.clear();

	for (IMesh* mesh : diffuse_meshes) render_context->DestroyStaticMesh(mesh);
	diffuse_meshes.clear();

	for (IMesh* mesh : triangle_meshes) render_context->DestroyStaticMesh(mesh);
	triangle_meshes.clear();
}

// Allocate buffers
FlexRenderer::FlexRenderer() {
	int num_threads = std::thread::hardware_concurrency();
	if (num_threads <= 0) num_threads = 8;	// can't detect, assume 8
	threads = new ThreadPool(num_threads);	// estimate number of threads
	//Msg("Initialized FlexRenderer with %i CPU threads\n", num_threads);
};

FlexRenderer::~FlexRenderer() {
	//if (materials->GetRenderContext() == nullptr) return;	// wtf?

	// threads are joined before removing all meshes to assure all meshes are destroyed, even ones being built in threads
	update_water();
	update_diffuse();
	update_cloth();
	destroy_meshes();

	delete threads;

	//if (water_buffer != nullptr) free(water_buffer);
	//if (diffuse_buffer != nullptr) free(diffuse_buffer);
	//if (water_meshes != nullptr) free(water_meshes);
	//if (queue != nullptr) free(queue);
};