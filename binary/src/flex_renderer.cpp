#include "flex_renderer.h"

void FlexRenderer::draw_imeshes() {
	for (IMesh* mesh : imeshes) 
		mesh->Draw();

};

void FlexRenderer::build_imeshes(FlexSolver* solver, float radius) {
	if (solver == nullptr) return;

	// Clear previous imeshes, they are being rebuilt
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
	float3 up = float3(view_matrix[1][0], view_matrix[1][1], view_matrix[1][2]);
	float3 right = float3(view_matrix[0][0], view_matrix[0][1], view_matrix[0][2]);

	// local Quad positions
	radius *= 0.5;
	float3 local_pos1 = -up - right * SQRT3;
	float3 local_pos2 = up * 2.0;
	float3 local_pos3 = -up + right * SQRT3;
	float3 local_pos[3] = {local_pos1 * radius, local_pos2 * radius, local_pos3 * radius};
	float u[3] = { 0.5 - SQRT3 / 2, 0.5, 0.5 + SQRT3 / 2};
	float v[3] = { 1, -0.5, 1 };

	// FleX data
	float4* particle_positions = solver->get_parameter("smoothing") != 0 ? solver->get_host("particle_smooth") : solver->get_host("particle_pos");
	float4* particle_ani1 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani1") : NULL;
	float4* particle_ani2 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani2") : NULL;
	float4* particle_ani3 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani3") : NULL;
	bool anisotropy_enabled = particle_ani1 && particle_ani2 && particle_ani3;

	CMeshBuilder mesh_builder;
	for (int particle_index = 0; particle_index < solver->get_active_particles();) {
		IMesh* imesh = render_context->CreateStaticMesh(VERTEX_POSITION | VERTEX_NORMAL | VERTEX_TEXCOORD0_2D, "");
		mesh_builder.Begin(imesh, MATERIAL_TRIANGLES, MAX_PRIMATIVES);
			for (int primative = 0; primative < MAX_PRIMATIVES && particle_index < solver->get_active_particles(); particle_index++) {
				float3 particle_pos = particle_positions[particle_index].xyz();

				// Frustrum culling
				Vector4D dst;
				Vector4DMultiply(view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
				if (dst.z < 0 || -dst.x - dst.w > radius || dst.x - dst.w > radius || -dst.y - dst.w > radius || dst.y - dst.w > radius) {
					continue;
				}

				float4 ani1 = float4();
				float4 ani2 = float4();
				float4 ani3 = float4();
				if (anisotropy_enabled) {
					ani1 = particle_ani1[particle_index];
					ani2 = particle_ani2[particle_index];
					ani3 = particle_ani3[particle_index];
				}

				for (int i = 0; i < 3; i++) {
					float3 pos_ani = local_pos[i];
					if (anisotropy_enabled) {
						pos_ani = pos_ani + ani1.xyz() * (pos_ani.dot(ani1.xyz()) * ani1.w);
						pos_ani = pos_ani + ani2.xyz() * (pos_ani.dot(ani2.xyz()) * ani2.w);
						pos_ani = pos_ani + ani3.xyz() * (pos_ani.dot(ani3.xyz()) * ani3.w);
					}

					float3 world_pos = particle_pos + pos_ani;
					mesh_builder.TexCoord2f(0, u[i], v[i]);
					mesh_builder.Position3f(world_pos.x, world_pos.y, world_pos.z);
					//mesh_builder.Normal3f(0, 0, 0);
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