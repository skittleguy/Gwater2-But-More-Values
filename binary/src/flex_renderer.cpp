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
	float3 up = float3(view_matrix[0][0], view_matrix[0][1], view_matrix[0][2]);
	float3 right = float3(view_matrix[1][0], view_matrix[1][1], view_matrix[1][2]);

	// local Quad positions
	radius *= 0.5;
	float3 local_pos1 = -up + right;
	float3 local_pos2 = up + right;
	float3 local_pos3 = up - right;
	float3 local_pos4 = -up - right; 
	float3 local_pos[4] = {local_pos1 * radius, local_pos2 * radius, local_pos3 * radius, local_pos4 * radius};

	// FleX data
	float4* particle_positions = solver->get_parameter("smoothing") != 0 ? solver->get_host("particle_smooth") : solver->get_host("particle_pos");
	float4* particle_ani1 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani1") : NULL;
	float4* particle_ani2 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani2") : NULL;
	float4* particle_ani3 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani3") : NULL;
	float4* particle_colors = solver->get_host("particle_col");
	bool anisotropy_enabled = particle_ani1 && particle_ani2 && particle_ani3;

	CMeshBuilder mesh_builder;
	for (int particle_index = 0; particle_index < solver->get_active_particles();) {
		IMesh* imesh = render_context->CreateStaticMesh(MATERIAL_VERTEX_FORMAT_MODEL_DX7, "");
		mesh_builder.Begin(imesh, MATERIAL_QUADS, MAX_PRIMATIVES);
			for (int primative = 0; primative < MAX_PRIMATIVES && particle_index < solver->get_active_particles(); particle_index++) {
				float3 particle_pos = particle_positions[particle_index].xyz();

				// Frustrum culling
				Vector4D dst;
				Vector4DMultiply(view_projection_matrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
				if (dst.z < 0 || -dst.x - dst.w > radius || dst.x - dst.w > radius || -dst.y - dst.w > radius || dst.y - dst.w > radius) {
					continue;
				}

				const float color[4] = {
					particle_colors[particle_index].x,
					particle_colors[particle_index].y,
					particle_colors[particle_index].z,
					particle_colors[particle_index].w
				};

				float4 ani1 = float4();
				float4 ani2 = float4();
				float4 ani3 = float4();
				if (anisotropy_enabled) {
					ani1 = particle_ani1[particle_index];
					ani2 = particle_ani2[particle_index];
					ani3 = particle_ani3[particle_index];
				}

				for (int i = 0; i < 4; i++) {
					float3 pos_ani = local_pos[i];
					if (anisotropy_enabled) {
						pos_ani = pos_ani + ani1.xyz() * (Dot(ani1.xyz(), pos_ani) * ani1.w);
						pos_ani = pos_ani + ani2.xyz() * (Dot(ani2.xyz(), pos_ani) * ani2.w);
						pos_ani = pos_ani + ani3.xyz() * (Dot(ani3.xyz(), pos_ani) * ani3.w);
					}

					float3 world_pos = particle_pos + pos_ani;
					mesh_builder.TexCoord2f(0, i == 1 || i == 2, i > 1);
					mesh_builder.Position3f(world_pos.x, world_pos.y, world_pos.z);
					mesh_builder.Normal3f(0, 0, 1);
					mesh_builder.Color4fv(color);
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