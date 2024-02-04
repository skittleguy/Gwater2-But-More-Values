#include "flex_renderer.h"

int FlexRenderer::get_total_imeshes() {
	if (!solver) return 0;

	return ceil((float)solver->get_max_particles() / MAX_INDICES);
};

void FlexRenderer::render_imeshes() {
	for (int i = 0; i < num_imeshes; i++) {
		imeshes[i]->Draw();
	}
};

void FlexRenderer::build_imeshes(float radius) {
	if (!solver) return;

	radius *= 0.5;

	IMatRenderContext* render_context = materials->GetRenderContext();
	CMeshBuilder meshBuilder;

	VMatrix viewMatrix, projectionMatrix, viewProjectionMatrix;
	render_context->GetMatrix(MATERIAL_VIEW, &viewMatrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projectionMatrix);
	MatrixMultiply(projectionMatrix, viewMatrix, viewProjectionMatrix);

	//float3 eye_pos = float3(viewMatrix[0][3], viewMatrix[1][3], viewMatrix[2][3]);
	float4* particle_positions = solver->get_parameter("smoothing") > 0 ? solver->get_host("particle_smooth") : solver->get_host("particle_pos");
	float4* particle_colors = solver->get_host("particle_col");

	int particle_index = 0;
	for (num_imeshes = 0; num_imeshes < get_total_imeshes(); num_imeshes++) {	// num_imeshes should never be equal to or greater than the number of maximum allocated meshes
		meshBuilder.Begin(imeshes[num_imeshes], MATERIAL_QUADS, MAX_INDICES / 4);
		for (int i = 0; i < MAX_INDICES / 4; particle_index++) {
			float3 particle_pos = float3(particle_positions[particle_index].x, particle_positions[particle_index].y, particle_positions[particle_index].z);

			float3 pos1 = particle_pos + float3(-radius, -radius, 0);
			float3 pos2 = particle_pos + float3(radius, -radius, 0);
			float3 pos3 = particle_pos + float3(radius, radius, 0);
			float3 pos4 = particle_pos + float3(-radius, radius, 0);

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

			meshBuilder.TexCoord2f(1, 0, 0);
			meshBuilder.Position3f(pos2.x, pos2.y, pos2.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(1, 1, 0);
			meshBuilder.Position3f(pos3.x, pos3.y, pos3.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, 1, 0);
			meshBuilder.Position3f(pos4.x, pos4.y, pos4.z);
			meshBuilder.Normal3f(0, 0, 1);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			i += 1;
		}
		meshBuilder.End();
		meshBuilder.Reset();
	}

};

FlexRenderer::FlexRenderer(FlexSolver* s) {
	if (!s) return;

	solver = s;
	imeshes = (IMesh**)malloc(sizeof(IMesh*) * get_total_imeshes());
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int i = 0; i < get_total_imeshes(); i++) {
		imeshes[i] = render_context->CreateStaticMesh(MATERIAL_VERTEX_FORMAT_MODEL_SKINNED, "");	// This function needs istudiorender.h to be included!
	}
};

FlexRenderer::~FlexRenderer() {
	IMatRenderContext* render_context = materials->GetRenderContext();
	for (int i = 0; i < get_total_imeshes(); i++) {
		render_context->DestroyStaticMesh(imeshes[i]);
	}
	free(imeshes);
};