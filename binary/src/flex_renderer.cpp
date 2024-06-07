#include "flex_renderer.h"

//extern IMaterialSystem* materials = NULL;	// stops main branch compile from bitching

// Not sure why this isn't defined in the standard math library
#define min(a, b) a < b ? a : b

float u[3] = { 0.5 - SQRT3 / 2, 0.5, 0.5 + SQRT3 / 2 };
float v[3] = { 1, -0.5, 1 };

void build_mesh(
	FlexRenderer* renderer,
	IMatRenderContext* render_context,
	Vector eye_pos,
	VMatrix view_projection_matrix,
	Vector4D* particle_positions,
	//Vector4D* particle_ani0,
	//Vector4D* particle_ani1,
	//Vector4D* particle_ani2,
	//bool particle_ani,
	int max_particles,
	float radius,
	int thread_id 
) {
	int start = thread_id * MAX_PRIMATIVES;
	int end = min((thread_id + 1) * MAX_PRIMATIVES, max_particles);

	IMesh* mesh = render_context->CreateStaticMesh(VERTEX_POSITION | VERTEX_NORMAL | VERTEX_TEXCOORD0_2D, "");
	renderer->get_water()[thread_id] = mesh;

	CMeshBuilder mesh_builder;
	mesh_builder.Begin(mesh, MATERIAL_TRIANGLES, MAX_PRIMATIVES);
	for (int particle_index = start; particle_index < end; ++particle_index) {
		Vector particle_pos = particle_positions[particle_index].AsVector3D();

		// Frustrum culling
		Vector4D dst;
		Vector4DMultiply(view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
		if (dst.z < 0 || -dst.x - dst.w > 0 || dst.x - dst.w > 0 || -dst.y - dst.w > 0 || dst.y - dst.w > 0) {
			continue;
		}

		// calculate triangle rotation
		//Vector forward = (eye_pos - particle_pos).Normalized();
		Vector forward = (particle_pos - eye_pos).Normalized();
		Vector right = forward.Cross(Vector(0, 0, 1)).Normalized();
		Vector up = right.Cross(forward);
		Vector local_pos[3] = { (-up - right * SQRT3), up * 2.0, (-up + right * SQRT3) };

#if 0
		//if (particle_ani) {
			Vector4D ani1 = particle_ani1[particle_index];
			Vector4D ani2 = particle_ani2[particle_index];
			Vector4D ani3 = particle_ani3[particle_index];

			for (int i = 0; i < 3; i++) {
				// Anisotropy warping (code provided by Spanky)
				Vector pos_ani = local_pos[i];
				pos_ani = pos_ani + ani1.AsVector3D() * (local_pos[i].Dot(ani1.AsVector3D()) * ani1.w);
				pos_ani = pos_ani + ani2.AsVector3D() * (local_pos[i].Dot(ani2.AsVector3D()) * ani2.w);
				pos_ani = pos_ani + ani3.AsVector3D() * (local_pos[i].Dot(ani3.AsVector3D()) * ani3.w);

				Vector world_pos = particle_pos + pos_ani;
				mesh_builder.TexCoord2f(0, u[i], v[i]);
				mesh_builder.Position3f(world_pos.x, world_pos.y, world_pos.z);
				mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
				mesh_builder.AdvanceVertex();
			}
		}
		//else {
#else
			for (int i = 0; i < 3; i++) { // Same as above w/o anisotropy warping
				Vector world_pos = particle_pos + local_pos[i] * radius;
				mesh_builder.TexCoord2f(0, u[i], v[i]);
				mesh_builder.Position3f(world_pos.x, world_pos.y, world_pos.z);
				mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
				mesh_builder.AdvanceVertex();
			}
#endif
		//}
	}
	mesh_builder.End();

	// mesh had no indices, bail
	if (mesh_builder.GetCurrentIndex() == 0) {
		renderer->get_water()[thread_id] = nullptr;
		render_context->DestroyStaticMesh(mesh);
	}
}

// lord have mercy brothers
void FlexRenderer::build_water(float radius) {
	if (flex == nullptr) return;

	// Clear previous imeshes since they are being rebuilt
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh_index = 0; mesh_index < water_max; mesh_index++) {
		if (water[mesh_index] != nullptr) {
			render_context->DestroyStaticMesh(water[mesh_index]);
			water[mesh_index] = nullptr;
		}
	}
	
	int max_particles = flex->get_active_particles();
	if (max_particles == 0) return;

	// View matrix, used in frustrum culling
	VMatrix view_matrix, projection_matrix, view_projection_matrix;
	render_context->GetMatrix(MATERIAL_VIEW, &view_matrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projection_matrix);
	MatrixMultiply(projection_matrix, view_matrix, view_projection_matrix);
	
	// Get eye position for sprite calculations
	Vector eye_pos; render_context->GetWorldSpaceCameraPosition(&eye_pos);

	Vector4D* particle_positions = flex->get_parameter("smoothing") != 0 ? (Vector4D*)flex->get_host("particle_smooth") : (Vector4D*)flex->get_host("particle_pos");
	Vector4D* particle_ani1 = (Vector4D*)flex->get_host("particle_ani1");
	Vector4D* particle_ani2 = (Vector4D*)flex->get_host("particle_ani2");
	Vector4D* particle_ani3 = (Vector4D*)flex->get_host("particle_ani3");
	bool particle_ani = flex->get_parameter("anisotropy_scale") != 0;

	// Split each mesh into its own thread
	std::thread** threads = (std::thread**)malloc(water_max * sizeof(std::thread*));
	for (int mesh_index = 0; mesh_index < water_max; mesh_index++) {
		threads[mesh_index] = new std::thread(
			build_mesh,
			this,
			render_context,
			eye_pos,
			view_projection_matrix,
			particle_positions,
			flex->get_active_particles(),
			radius,
			mesh_index
		);
	}

	for (int mesh_index = 0; mesh_index < water_max; mesh_index++) {
		threads[mesh_index]->join();
	}

	free(threads);
};

void FlexRenderer::build_diffuse(float radius) {
	// IMPLEMENT ME!
};

void FlexRenderer::draw_diffuse() {
	// IMPLEMENT ME!
};

void FlexRenderer::draw_water() {
	for (int mesh = 0; mesh < allocated; mesh++) {
		if (thread_status[mesh] == MESH_NONE) continue;

		water[mesh]->Draw();
	}
};

FlexRenderer::FlexRenderer(int max_meshes) {
	allocated = max_meshes;
	water = (IMesh**)malloc(allocated * sizeof(IMesh*));
	thread_status = (ThreadStatus*)malloc(allocated * sizeof(ThreadStatus));
	memset(thread_status, MESH_NONE, allocated * sizeof(ThreadStatus));
};

FlexRenderer::~FlexRenderer() {
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int mesh = 0; mesh < water_max; mesh++) {
		if (thread_status[mesh] == MESH_NONE) continue;
		render_context->DestroyStaticMesh(water[mesh]);
	}

	free(water);
};