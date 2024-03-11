#include "flex_renderer.h"

//extern IMaterialSystem* materials = NULL;	// stops main branch compile from bitching

void FlexRenderer::draw_imeshes() {
	for (IMesh* mesh : imeshes) 
		mesh->Draw();
};

// lord have mercy brothers
void FlexRenderer::build_imeshes(FlexSolver* solver, float radius) {
	if (solver == nullptr) return;

	// Clear previous imeshes since they are being rebuilt
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (IMesh* mesh : imeshes)
		render_context->DestroyStaticMesh(mesh);
	imeshes.clear();
	
	if (solver->get_active_particles() == 0) return;

	// View matrix, used in frustrum culling
	VMatrix view_matrix, projection_matrix, view_projection_matrix;
	render_context->GetMatrix(MATERIAL_VIEW, &view_matrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projection_matrix);
	MatrixMultiply(projection_matrix, view_matrix, view_projection_matrix);
	
	// Get eye position for sprite calculations
	Vector ep; render_context->GetWorldSpaceCameraPosition(&ep);
	float3 eye_pos = float3(ep.x, ep.y, ep.z);

	float radius2 = radius * 0.5;
	float u[3] = { 0.5 - SQRT3 / 2, 0.5, 0.5 + SQRT3 / 2};
	float v[3] = { 1, -0.5, 1 };

	float4* particle_positions = solver->get_parameter("smoothing") != 0 ? solver->get_host("particle_smooth") : solver->get_host("particle_pos");
	float4* particle_ani1 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani1") : 0;
	float4* particle_ani2 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani2") : 0;
	float4* particle_ani3 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani3") : 0;

	CMeshBuilder mesh_builder;
	for (int particle_index = 0; particle_index < solver->get_active_particles();) {
		IMesh* imesh = render_context->CreateStaticMesh(VERTEX_POSITION | VERTEX_NORMAL | VERTEX_TEXCOORD0_2D, "");
		mesh_builder.Begin(imesh, MATERIAL_TRIANGLES, MAX_PRIMATIVES);
			for (int primative = 0; primative < MAX_PRIMATIVES && particle_index < solver->get_active_particles(); particle_index++) {
				float3 particle_pos = particle_positions[particle_index].xyz();

				// Frustrum culling
				Vector4D dst;
				Vector4DMultiply(view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
				if (dst.z < 0 || -dst.x - dst.w > 0 || dst.x - dst.w > 0 || -dst.y - dst.w > 0 || dst.y - dst.w > 0) {
					continue;
				}

				// calculate triangle rotation
				float3 forward = Normalize(particle_pos - eye_pos);
				float3 right = Normalize(forward.cross(float3(0, 0, 1)));
				float3 up = right.cross(forward);
				float3 local_pos[3] = { (-up - right * SQRT3), up * 2.0, (-up + right * SQRT3) };

				float4 ani1 = particle_ani1 ? particle_ani1[particle_index] : 0;
				float4 ani2 = particle_ani2 ? particle_ani2[particle_index] : 0;
				float4 ani3 = particle_ani3 ? particle_ani3[particle_index] : 0;

				for (int i = 0; i < 3; i++) {
					// Anisotropy warping
					float3 pos_ani = local_pos[i];
					pos_ani = pos_ani + ani1.xyz() * (local_pos[i].dot(ani1.xyz()) * ani1.w);
					pos_ani = pos_ani + ani2.xyz() * (local_pos[i].dot(ani2.xyz()) * ani2.w);
					pos_ani = pos_ani + ani3.xyz() * (local_pos[i].dot(ani3.xyz()) * ani3.w);

					float3 world_pos = particle_pos + pos_ani * radius2;
					mesh_builder.TexCoord2f(0, u[i], v[i]);
					mesh_builder.Position3f(world_pos.x, world_pos.y, world_pos.z);
					mesh_builder.Normal3f(-forward.x, -forward.y, -forward.z);
					mesh_builder.AdvanceVertex();
				}

				primative += 1;
			}
		mesh_builder.End();
		mesh_builder.Reset();
		imeshes.push_back(imesh);
	}
};

FlexRenderer::FlexRenderer() {
	imeshes = std::vector<IMesh*>();
};

FlexRenderer::~FlexRenderer() {
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (IMesh* mesh : imeshes) 
		render_context->DestroyStaticMesh(mesh);
	
	imeshes.clear();
};