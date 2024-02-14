#include "flex_renderer.h"

void FlexRenderer::draw_imeshes() {
	for (IMesh* mesh : imeshes) {
		mesh->Draw();
	}
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
	VMatrix viewMatrix, projectionMatrix, viewProjectionMatrix;
	render_context->GetMatrix(MATERIAL_VIEW, &viewMatrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projectionMatrix);
	MatrixMultiply(projectionMatrix, viewMatrix, viewProjectionMatrix);
	float3 up = float3(viewMatrix[0][0], viewMatrix[0][1], viewMatrix[0][2]);
	float3 right = float3(viewMatrix[1][0], viewMatrix[1][1], viewMatrix[1][2]);

	// local Quad positions
	radius *= 0.5;
	float3 local_pos1 = -up + right; local_pos1 = local_pos1 * radius;
	float3 local_pos2 = up + right; local_pos2 = local_pos2 * radius;
	float3 local_pos3 = up - right; local_pos3 = local_pos3 * radius;
	float3 local_pos4 = -up - right; local_pos4 = local_pos4 * radius;

	// FleX data
	float4* particle_positions = solver->get_parameter("smoothing") != 0 ? solver->get_host("particle_smooth") : solver->get_host("particle_pos");
	float4* particle_ani1 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani1") : NULL;
	float4* particle_ani2 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani2") : NULL;
	float4* particle_ani3 = solver->get_parameter("anisotropy_scale") > 0 ? solver->get_host("particle_ani3") : NULL;
	float4* particle_colors = solver->get_host("particle_col");

	CMeshBuilder meshBuilder;
	for (int particle_index = 0; particle_index < solver->get_active_particles();) {
		IMesh* imesh = render_context->CreateStaticMesh(MATERIAL_VERTEX_FORMAT_MODEL_DX7, "");
		meshBuilder.Begin(imesh, MATERIAL_QUADS, MAX_PRIMATIVES);
		for (int i = 0; i < MAX_PRIMATIVES && particle_index < solver->get_active_particles(); particle_index++) {
			float3 particle_pos = float3(particle_positions[particle_index].x, particle_positions[particle_index].y, particle_positions[particle_index].z);

			/*
			// Frustrum culling
			Vector4D dst;
			Vector4DMultiply(viewProjectionMatrix, Vector4D(particle_pos.x, particle_pos.y, particle_pos.z, 1), dst);
			//dst.x /= dst.z;
			//dst.y /= dst.z;
			float xbound = -dst.x - dst.w;
			if (dst.z < 0 || xbound < 0) {//dst.x < -radius || dst.x > radius || dst.y < -radius || dst.y > radius) {
				continue;
			}*/

			float3 pos1 = particle_pos + local_pos1;
			float3 pos2 = particle_pos + local_pos2;
			float3 pos3 = particle_pos + local_pos3;
			float3 pos4 = particle_pos + local_pos4;

			float color[4] = {
				particle_colors[particle_index].x,
				particle_colors[particle_index].y,
				particle_colors[particle_index].z,
				particle_colors[particle_index].w
			};
			
			meshBuilder.TexCoord2f(0, 0, 0);
			meshBuilder.Position3f(pos1.x, pos1.y, pos1.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, 1, 0);
			meshBuilder.Position3f(pos2.x, pos2.y, pos2.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, 1, 1);
			meshBuilder.Position3f(pos3.x, pos3.y, pos3.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, 0, 1);
			meshBuilder.Position3f(pos4.x, pos4.y, pos4.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			i += 1;
		}
		meshBuilder.End();
		meshBuilder.Reset();
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