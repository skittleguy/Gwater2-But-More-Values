#include "GarrysMod/Lua/Interface.h"

// bsp parser requirements
// this MUST BE included before shader_inject.h because of conflicting source defines
#include "GMFS.h"
#include "BSPParser.h"

#include "flex_solver.h"
#include "flex_renderer.h"
#include "shader_inject.h"

using namespace GarrysMod::Lua;

NvFlexLibrary* FLEX_LIBRARY;	// Main FleX library, handles all solvers. ("The heart of all that is FleX" - andreweathan)
ILuaBase* GLOBAL_LUA;			// used for flex error handling
int FLEXSOLVER_METATABLE = 0;
int FLEXRENDERER_METATABLE = 0;

//#define GET_FLEX(type, stack_pos) LUA->GetUserType<type>(stack_pos, type == FlexSolver ? FLEXSOLVER_METATABLE : FLEXRENDERER_METATABLE)

/************************** Flex Solver LUA Interface *******************************/

#define GET_FLEXSOLVER(stack_pos) LUA->GetUserType<FlexSolver>(stack_pos, FLEXSOLVER_METATABLE)

// todo: probably need to move these defines somewhere else or remove them
float3 VectorTofloat3(Vector v) {
	return float3(v.x, v.y, v.z);
}

// Warning: allocates memory which MUST be freed!
// todo: this is shit. the physics mesh library should be rewritten
float3* TableTofloat3(ILuaBase* LUA) {
	const int num_vertices = LUA->ObjLen(2);
	float3* verts = reinterpret_cast<float3*>(malloc(sizeof(float3) * num_vertices));
	for (int i = 0; i < num_vertices; i++) {
		LUA->PushNumber(i + 1);   //lua is 1 indexed
		LUA->GetTable(2);
		LUA->GetField(-1, "pos");

		Vector pos = LUA->GetType(-2) == Type::Vector ? LUA->GetVector(-2) : LUA->GetVector();
		verts[i] = float3(pos.x, pos.y, pos.z);
		LUA->Pop(2); //pop table & position
	}

	return verts;
}

// Frees the flex solver instance from memory
// For some reason the vram only gets freed when the LIBRARY is shut down
LUA_FUNCTION(FLEXSOLVER_GarbageCollect) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);

	FlexSolver* flex = GET_FLEXSOLVER(1);

	LUA->PushNil();
	LUA->SetMetaTable(-2);

	delete flex;
	flex = nullptr;
	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddParticle) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Vector);	// position
	LUA->CheckType(3, Type::Vector);	// velocity
	LUA->CheckType(4, Type::Table);		// color
	LUA->CheckNumber(5);				// mass

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Vector pos = LUA->GetVector(2);
	Vector vel = LUA->GetVector(3);
	float inv_mass = 1.f / (float)LUA->GetNumber(5);	// FleX uses inverse mass for their calculations

	// Push color data onto stack (annoying)
	LUA->GetField(4, "r");
	LUA->GetField(4, "g");
	LUA->GetField(4, "b");
	LUA->GetField(4, "a");
	
	flex->add_particle(
		float4(pos.x, pos.y, pos.z, inv_mass), 
		float3(vel.x, vel.y, vel.z), 
		float4(LUA->GetNumber(-4) / 255.f, LUA->GetNumber(-3) / 255.f, LUA->GetNumber(-2) / 255.f, LUA->GetNumber(-1) / 255.f)	// color
	);

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_Tick) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	float dt = (float)LUA->GetNumber(2);
	bool succ = flex->pretick((NvFlexMapFlags)LUA->GetNumber(3));
	if (succ) flex->tick(dt);

	LUA->PushBool(succ);
	return 1;
}

// Gets all the particle positions in a FlexSolver. Originally used for debugging
LUA_FUNCTION(FLEXSOLVER_GetParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	LUA->CreateTable();
	for (int i = 0; i < flex->get_active_particles(); i++) {
		float4 pos = flex->get_host("particle_pos")[i];
		LUA->PushNumber(i + 1);
		LUA->PushVector(Vector(pos.x, pos.y, pos.z));
		LUA->SetTable(-3);
	}

	return 1;
}

// Adds a triangle collision mesh to a FlexSolver
LUA_FUNCTION(FLEXSOLVER_AddConcaveMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Table);		// Mesh data
	LUA->CheckType(3, Type::Vector);	// Initial Pos
	LUA->CheckType(4, Type::Angle);		// Initial Angle

	Vector pos = LUA->GetVector(3);
	QAngle ang = LUA->GetAngle(4);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Mesh* mesh = new Mesh(FLEX_LIBRARY);
	float3* verts = TableTofloat3(LUA);
	if (!mesh->init_concave(verts, LUA->ObjLen(2))) {
		free(verts);
		LUA->ThrowError("Tried to add concave mesh with invalid data (NumVertices is not a multiple of 3!)");
		return 0;
	}
	free(verts);
	mesh->update(float3(pos.x, pos.y, pos.z), float3(ang.x, ang.y, ang.z));
	flex->add_mesh(mesh, eNvFlexShapeTriangleMesh, true);

	return 0;
}

// Adds a convex collision mesh to a FlexSolver
LUA_FUNCTION(FLEXSOLVER_AddConvexMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Table);		// Mesh data
	LUA->CheckType(3, Type::Vector);	// Initial Pos
	LUA->CheckType(4, Type::Angle);		// Initial Angle

	Vector pos = LUA->GetVector(3);
	QAngle ang = LUA->GetAngle(4);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Mesh* mesh = new Mesh(FLEX_LIBRARY);
	float3* verts = TableTofloat3(LUA);
	if (!mesh->init_convex(verts, LUA->ObjLen(2))) {
		free(verts);
		LUA->ThrowError("Tried to add convex mesh with invalid data (NumVertices is not a multiple of 3!)");
		return 0;
	}
	free(verts);

	mesh->update(float3(pos.x, pos.y, pos.z), float3(ang.x, ang.y, ang.z));
	flex->add_mesh(mesh, eNvFlexShapeConvexMesh, true);

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_RemoveMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2); // Mesh ID

	FlexSolver* flex = GET_FLEXSOLVER(1);
	flex->remove_mesh(LUA->GetNumber(2));

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_SetParameter) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckString(2); // Param
	LUA->CheckNumber(3); // Number

	FlexSolver* flex = GET_FLEXSOLVER(1);

	bool succ = flex->set_parameter(LUA->GetString(2), LUA->GetNumber(3));
	if (!succ) LUA->ThrowError(("Attempt to set invalid parameter '" + (std::string)LUA->GetString(2) + "'").c_str());

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_GetParameter) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckString(2); // Param

	FlexSolver* flex = GET_FLEXSOLVER(1);
	float value = flex->get_parameter(LUA->GetString(2));

	if (isnan(value)) LUA->ThrowError(("Attempt to get invalid parameter '" + (std::string)LUA->GetString(2) + "'").c_str());

	LUA->PushNumber(value);
	return 1;
}

// Updates position and angles of a mesh collider
LUA_FUNCTION(FLEXSOLVER_UpdateMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Mesh ID
	LUA->CheckType(3, Type::Vector);	// Prop Pos
	LUA->CheckType(4, Type::Angle);		// Prop Angle

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Vector pos = LUA->GetVector(3);
	QAngle ang = LUA->GetAngle(4);

	flex->update_mesh(LUA->GetNumber(2), float3(pos.x, pos.y, pos.z), float3(ang.x, ang.y, ang.z));

	return 0;
}

// removes all particles in a flex solver
LUA_FUNCTION(FLEXSOLVER_Reset) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	flex->set_active_particles(0);

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_GetCount) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	LUA->PushNumber(flex->get_active_particles());
	return 1;
}

// Iterates through all particles and calls a lua function with 1 parameter (position) (also does frustrum culling)
LUA_FUNCTION(FLEXSOLVER_RenderParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Function);

	FlexSolver* flex = GET_FLEXSOLVER(1);

	float4* host = flex->get_host("particle_pos");
	for (int i = 0; i < flex->get_active_particles(); i++) {
		// render function
		LUA->Push(2);
		LUA->PushVector(Vector(host[i].x, host[i].y, host[i].z));
		LUA->Call(1, 0);
	}

	return 0;
}
/*
// todo: move this into FlexRenderer
#define MAX_INDICES 65535
LUA_FUNCTION(FLEXSOLVER_BuildIMeshes) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);

	LUA->CheckNumber(7);				// radius

	// Defines
	FlexSolver* flex = GET_FLEX;

	float radius = LUA->GetNumber(7) * 0.625;	// Magic number 1 (also equal to 5/8?)

	IMatRenderContext* render_context = materials->GetRenderContext();
	CMeshBuilder meshBuilder;

	VMatrix viewMatrix, projectionMatrix, viewProjectionMatrix;
	render_context->GetMatrix(MATERIAL_VIEW, &viewMatrix);
	render_context->GetMatrix(MATERIAL_PROJECTION, &projectionMatrix);
	MatrixMultiply(projectionMatrix, viewMatrix, viewProjectionMatrix);

	float3 eye_pos = float3(viewMatrix[0][3], viewMatrix[1][3], viewMatrix[2][3]);

	// destroy our stored imeshes since they are being replaced with new ones
	for (IMesh* mesh : flex->imeshes) render_context->DestroyStaticMesh(mesh);
	flex->imeshes.clear();

	int particle_count = flex->get_active_particles();
	for (int particle_index = 0; particle_index < particle_count;) {
		//IMesh* pMesh = pRenderContext->GetDynamicMesh();
		IMesh* pMesh = render_context->CreateStaticMesh(MATERIAL_VERTEX_FORMAT_MODEL_SKINNED, "");	// This function needs istudiorender.h to be included!

		float4* particle_pos = flex->get_parameter("smoothing") > 0 ? flex->get_host("particle_smooth") : flex->get_host("particle_pos");
		float4* particle_ani1 = flex->get_parameter("anisotropy_scale") > 0 ? flex->get_host("particle_ani1") : NULL;
		float4* particle_ani2 = flex->get_parameter("anisotropy_scale") > 0 ? flex->get_host("particle_ani2") : NULL;
		float4* particle_ani3 = flex->get_parameter("anisotropy_scale") > 0 ? flex->get_host("particle_ani3") : NULL;
		float4* particle_col = flex->get_host("particle_col");
		meshBuilder.Begin(pMesh, MATERIAL_TRIANGLES, MAX_INDICES);
		for (int indice = 0; particle_index < particle_count && indice < MAX_INDICES;) {
			float3 particle = float3(particle_pos[particle_index].x, particle_pos[particle_index].y, particle_pos[particle_index].z);

			// Frustrum culling
			Vector dst;
			Vector3DMultiply(viewProjectionMatrix, Vector(particle.x, particle.y, particle.z), dst);
			if (dst.x < -radius || dst.x > radius || dst.y < -radius || dst.y > radius || dst.z < -radius || dst.z > radius) {
				particle_index++;
				continue;
			}

			float3 dir = Normalize(dir);
			float3 eye_right = Normalize(Cross(dir, float3(0, 0, 1)));
			float3 eye_up = Cross(eye_right, dir);

			// particle positions in local space
			float tri_mult = 1.3660254; //1.0 / ((2.0 * sqrt(3) - 2.0) / 2.0);	// Inverse Height of equalateral triangle minus length of circle with radius 1
			float3 offset = -eye_up * 0.8;	// Magic number 2
			float3 pos1 = (eye_up + eye_up * tri_mult + offset) * radius;
			float3 pos2 = (eye_right * tri_mult + offset) * radius;
			float3 pos3 = (-eye_right * tri_mult + offset) * radius;

			float4 ani1 = particle_ani1 ? particle_ani1[particle_index] : 0;
			float4 ani2 = particle_ani2 ? particle_ani2[particle_index] : 0;
			float4 ani3 = particle_ani3 ? particle_ani3[particle_index] : 0;

			// Flatten vectors for anisotropy
			float3 anisotropy_xyz_1 = float3(ani1.x, ani1.y, ani1.z);
			float3 anisotropy_xyz_2 = float3(ani2.x, ani2.y, ani2.z);
			float3 anisotropy_xyz_3 = float3(ani3.x, ani3.y, ani3.z);

			float anisotropy_w1 = ani1.w;
			float anisotropy_w2 = ani2.w;
			float anisotropy_w3 = ani3.w;

			pos1 = pos1 + anisotropy_xyz_1 * Dot(anisotropy_xyz_1, pos1) * anisotropy_w1;
			pos1 = pos1 + anisotropy_xyz_2 * Dot(anisotropy_xyz_2, pos1) * anisotropy_w2;
			pos1 = pos1 + anisotropy_xyz_3 * Dot(anisotropy_xyz_3, pos1) * anisotropy_w3;

			pos2 = pos2 + anisotropy_xyz_1 * Dot(anisotropy_xyz_1, pos2) * anisotropy_w1;
			pos2 = pos2 + anisotropy_xyz_2 * Dot(anisotropy_xyz_2, pos2) * anisotropy_w2;
			pos2 = pos2 + anisotropy_xyz_3 * Dot(anisotropy_xyz_3, pos2) * anisotropy_w3;

			pos3 = pos3 + anisotropy_xyz_1 * Dot(anisotropy_xyz_1, pos3) * anisotropy_w1;
			pos3 = pos3 + anisotropy_xyz_2 * Dot(anisotropy_xyz_2, pos3) * anisotropy_w2;
			pos3 = pos3 + anisotropy_xyz_3 * Dot(anisotropy_xyz_3, pos3) * anisotropy_w3;

			// translate to particle position
			pos1 = pos1 + particle;
			pos2 = pos2 + particle;
			pos3 = pos3 + particle;

			float normal[3] = { -(dir.x), -(dir.y), -(dir.z) };
			float userdata[4] = { 0.f, 0.f, 0.f, 0.f };
			float color[4] = { particle_col[particle_index].x , particle_col[particle_index].y, particle_col[particle_index].z, particle_col[particle_index].w };

			meshBuilder.TexCoord2f(0, 0.5, -0.5);
			meshBuilder.Position3f(pos1.x, pos1.y, pos1.z);
			meshBuilder.Normal3fv(normal);
			meshBuilder.UserData(userdata);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, tri_mult, 1);
			meshBuilder.Position3f(pos2.x, pos2.y, pos2.z);
			meshBuilder.Normal3fv(normal);
			meshBuilder.UserData(userdata);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			meshBuilder.TexCoord2f(0, 1.0 - tri_mult, 1);
			meshBuilder.Position3f(pos3.x, pos3.y, pos3.z);
			meshBuilder.Normal3fv(normal);
			meshBuilder.UserData(userdata);
			meshBuilder.Color4fv(color);
			meshBuilder.AdvanceVertex();

			particle_index++;
			indice += 3;
		}
		meshBuilder.End();
		flex->imeshes.push_back(pMesh);
		meshBuilder.Reset();
	}

	return 0;
}*/
/*
LUA_FUNCTION(RenderIMeshes) {
	LUA->CheckType(1, FLEX_META_TABLE);
	FlexSolver* flex = GET_FLEX;
	for (IMesh* mesh : flex->imeshes) {
		mesh->Draw();
	};
	//materials->GetRenderContext()->Draw()

	LUA->PushNumber(flex->imeshes.size() * MAX_INDICES);
	return 1;
}*/

// todo: rewrite this shit
LUA_FUNCTION(FLEXSOLVER_AddMapMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckString(2);

	FlexSolver* flex = GET_FLEXSOLVER(1);

	// Get path, check if it exists
	std::string path = "maps/" + (std::string)LUA->GetString(2) + ".bsp";
	if (!FileSystem::Exists(path.c_str(), "GAME")) {
		LUA->ThrowError(("[GWater2 Internal Error]: Map path " + path + " not found! (Is the map subscribed to?)").c_str());
		return 0;
	}

	// Path exists, load data
	FileHandle_t file = FileSystem::Open(path.c_str(), "rb", "GAME");
	uint32_t filesize = FileSystem::Size(file);
	uint8_t* data = (uint8_t*)malloc(filesize);
	if (data == nullptr) {
		LUA->ThrowError("[GWater2 Internal Error]: Map collision data failed to load!");
		return 0;
	}
	FileSystem::Read(data, filesize, file);
	FileSystem::Close(file);

	BSPMap map = BSPMap(data, filesize);
	Mesh* mesh = new Mesh(FLEX_LIBRARY);
	if (!mesh->init_concave((float3*)map.GetVertices(), map.GetNumTris() * 3)) {
		free(data);
		LUA->ThrowError("Tried to add map mesh with invalid data (NumVertices is 0 or not a multiple of 3!)");

		return 0;
	}

	free(data);
	flex->add_mesh(mesh, eNvFlexShapeTriangleMesh, false);

	return 0;
}

/*
* Returns a table of contact data. The table isnt sequential (do NOT use ipairs!) and in the format {[MeshIndex] = {ind1, cont1, pos1, vel1, ind2, cont2, pos2, vel2, ind3, cont3, pos3, vel3, etc...}
* Note that this function is quite expensive! It is a large table being generated.
* @param[in] solver The FlexSolver to return contact data for
* @param[in] buoyancymul A multiplier to the velocity of prop->water interation
*/
//FIXME: MOVE THIS FUNCTION TO THE FLEX_SOLVER CLASS
/*
LUA_FUNCTION(GetContacts) {
	LUA->CheckType(1, FlexMetaTable);
	LUA->CheckNumber(2);	// multiplier

	FlexSolver* flex = GET_FLEX;
	float4* pos = flex->get_host("particle_pos");
	float3* vel = (float3*)NvFlexMap(flex->getBuffer("particle_vel"), eNvFlexMapWait);
	float4* contact_vel = (float4*)NvFlexMap(flex->getBuffer("contact_vel"), eNvFlexMapWait);
	float4* planes = (float4*)NvFlexMap(flex->getBuffer("contact_planes"), eNvFlexMapWait);
	int* count = (int*)NvFlexMap(flex->getBuffer("contact_count"), eNvFlexMapWait);
	int* indices = (int*)NvFlexMap(flex->getBuffer("contact_indices"), eNvFlexMapWait);
	int max_contacts = flex->get_max_contacts();
	float radius = flex->get_parameter(LUA, "radius");
	float buoyancy_mul = LUA->GetNumber(2);
	std::map<int, Mesh*> props;

	// Get all props and average them
	for (int i = 0; i < flex->get_active_particles(); i++) {
		int particle = indices[i];
		for (int contact = 0; contact < count[particle]; contact++) {
		
			// Get force of impact (w/o friction) by multiplying plane direction by dot of hitnormal (incoming velocity)
			// incase particles are being pushed by it subtract velocity of mesh 
			int index = particle * max_contacts + contact;
			int prop_id = contact_vel[index].w;
			float3 plane = planes[index];
			float3 prop_pos = float3(pos[i]) - plane * radius;
			float3 impact_vel = plane * fmin(Dot(vel[i], plane), 0) - contact_vel[index] * buoyancy_mul;

			try {
				Mesh* prop = props.at(prop_id);
				prop->pos = prop->pos + float4(prop_pos.x, prop_pos.y, prop_pos.z, 1);
				prop->ang = prop->ang + float4(impact_vel.x, impact_vel.y, impact_vel.z, 0);
			}
			catch (std::exception e) {
				props[prop_id] = new Mesh(flexLibrary);
				props[prop_id]->pos = float4(prop_pos.x, prop_pos.y, prop_pos.z, 1);
				props[prop_id]->ang = float4(impact_vel.x, impact_vel.y, impact_vel.z, 0);
			}
		}
	}

	NvFlexUnmap(flex->getBuffer("particle_vel"));
	NvFlexUnmap(flex->getBuffer("contact_vel"));
	NvFlexUnmap(flex->getBuffer("contact_planes"));
	NvFlexUnmap(flex->getBuffer("contact_count"));
	NvFlexUnmap(flex->getBuffer("contact_indices"));
	
	// Average data together
	Vector pushvec = Vector();
	LUA->CreateTable();
	for (std::pair<int, Mesh*> prop : props) {
		int len = LUA->ObjLen();

		// Prop index
		LUA->PushNumber(len + 1);
		LUA->PushNumber(prop.first);
		LUA->SetTable(-3);

		// Number of particles contacting prop
		float average = prop.second->pos.w;
		LUA->PushNumber(len + 2);
		LUA->PushNumber(average);
		LUA->SetTable(-3);

		// Average position
		pushvec.x = prop.second->pos.x / average;
		pushvec.y = prop.second->pos.y / average;
		pushvec.z = prop.second->pos.z / average;
		LUA->PushNumber(len + 3);
		LUA->PushVector(pushvec);
		LUA->SetTable(-3);

		// Average velocity
		pushvec.x = prop.second->ang.x / average;
		pushvec.y = prop.second->ang.y / average;
		pushvec.z = prop.second->ang.z / average;
		LUA->PushNumber(len + 4);
		LUA->PushVector(pushvec);
		LUA->SetTable(-3);

		delete prop.second;
	}
	
	return 1;
}*/

// Original function written by andreweathan
LUA_FUNCTION(FLEXSOLVER_AddCube) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Vector); // pos
	LUA->CheckType(3, Type::Vector); // vel
	LUA->CheckType(4, Type::Vector); // cube size
	LUA->CheckType(5, Type::Number); // size apart (usually radius)
	LUA->CheckType(6, Type::Table);	// color (table w/ .r .g .b .a)

	//gmod Vector and fleX float4
	FlexSolver* flex = GET_FLEXSOLVER(1);
	float3 gmodPos = VectorTofloat3(LUA->GetVector(2));		//pos
	float3 gmodVel = VectorTofloat3(LUA->GetVector(3));		//vel
	float3 gmodSize = VectorTofloat3(LUA->GetVector(4));	//size
	float size = LUA->GetNumber(5);			//size apart

	// Push color data onto stack (annoying)
	LUA->GetField(6, "r");
	LUA->GetField(6, "g");
	LUA->GetField(6, "b");
	LUA->GetField(6, "a");

	float4 rgba = float4(LUA->GetNumber(-4) / 255, LUA->GetNumber(-3) / 255, LUA->GetNumber(-2) / 255, LUA->GetNumber(-1) / 255);

	gmodSize = gmodSize / 2.f;
	gmodPos = gmodPos + float3(size) / 2.0;

	for (float z = -gmodSize.z; z < gmodSize.z; z++) {
		for (float y = -gmodSize.y; y < gmodSize.y; y++) {
			for (float x = -gmodSize.x; x < gmodSize.x; x++) {
				float3 newPos = float3(x, y, z) * size + gmodPos;

				flex->add_particle(float4(newPos.x, newPos.y, newPos.z, 1), gmodVel, rgba);
			}
		}
	}

	return 0;
}

// Initializes a box (6 planes) with a mins and maxs on a FlexSolver
// Inputting nil disables the bounds.
LUA_FUNCTION(FLEXSOLVER_InitBounds) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	if (LUA->GetType(2) == Type::Vector && LUA->GetType(3) == Type::Vector) {
		flex->enable_bounds(VectorTofloat3(LUA->GetVector(2)), VectorTofloat3(LUA->GetVector(3)));
	} else {
		flex->disable_bounds();
	}
	
	return 0;
}


/*********************************** Flex Renderer LUA Interface *******************************************/

#define GET_FLEXRENDERER(stack_pos) LUA->GetUserType<FlexRenderer>(stack_pos, FLEXRENDERER_METATABLE)

// Frees the flex renderer and its allocated meshes from memory
LUA_FUNCTION(FLEXRENDERER_GarbageCollect) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	FlexRenderer* flex = GET_FLEXRENDERER(1);

	LUA->PushNil();
	LUA->SetMetaTable(-2);

	delete flex;
	flex = nullptr;
	return 0;
}

LUA_FUNCTION(FLEXRENDERER_BuildIMeshes) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	LUA->CheckType(2, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(3);

	GET_FLEXRENDERER(1)->build_imeshes(GET_FLEXSOLVER(2), LUA->GetNumber(3));

	return 0;
}

LUA_FUNCTION(FLEXRENDERER_DrawIMeshes) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	GET_FLEXRENDERER(1)->draw_imeshes();

	return 0;
}

/************************************* Global LUA Interface **********************************************/

#define ADD_FUNCTION(LUA, funcName, tblName) LUA->PushCFunction(funcName); LUA->SetField(-2, tblName)

// must be freed from memory
LUA_FUNCTION(NewFlexSolver) {
	LUA->CheckNumber(1);
	if (LUA->GetNumber(1) <= 0) LUA->ThrowError("Max Particles must be a positive number!");

	FlexSolver* flex = new FlexSolver(FLEX_LIBRARY, LUA->GetNumber(1));

	LUA->PushUserType(flex, FLEXSOLVER_METATABLE);
	LUA->PushMetaTable(FLEXSOLVER_METATABLE);	// Add our meta functions
	LUA->SetMetaTable(-2);

	return 1;
}

// ^
LUA_FUNCTION(NewFlexRenderer) {
	FlexRenderer* flex_renderer = new FlexRenderer();

	LUA->PushUserType(flex_renderer, FLEXRENDERER_METATABLE);
	LUA->PushMetaTable(FLEXRENDERER_METATABLE);
	LUA->SetMetaTable(-2);

	return 1;
}

// ShaderDevice is assumed to exist since if it didnt, this function wouldn't be accessable by lua
LUA_FUNCTION(IsMSAAEnabled) {
	LUA->PushBool(g_pShaderDevice->IsAAEnabled());
	return 1;
}

GMOD_MODULE_OPEN() {
	GLOBAL_LUA = LUA;
	FLEX_LIBRARY = NvFlexInit(
		NV_FLEX_VERSION, 
		[](NvFlexErrorSeverity type, const char* message, const char* file, int line) {
			std::string error = "[GWater2 Internal Error]: " + (std::string)message;
			GLOBAL_LUA->ThrowError(error.c_str());
		}
	);

	if (!FLEX_LIBRARY) 
		LUA->ThrowError("[GWater2 Internal Error]: Nvidia FleX Failed to load! (Does your GPU meet the minimum requirements to run FleX?)");

	if (!Sys_LoadInterface("materialsystem", MATERIAL_SYSTEM_INTERFACE_VERSION, NULL, (void**)&materials))
		LUA->ThrowError("[GWater2 Internal Error]: C++ Materialsystem failed to load!");

	if (!Sys_LoadInterface("shaderapidx9", SHADER_DEVICE_INTERFACE_VERSION, NULL, (void**)&g_pShaderDevice))
		LUA->ThrowError("[GWater2 Internal Error]: C++ Shaderdevice failed to load!");

	//if (!Sys_LoadInterface("shaderapidx9", SHADERAPI_INTERFACE_VERSION, NULL, (void**)&g_pShaderAPI))
	//	LUA->ThrowError("[GWater2 Internal Error]: C++ Shaderapi failed to load!");

	//if (!Sys_LoadInterface("studiorender", STUDIO_RENDER_INTERFACE_VERSION, NULL, (void**)&g_pStudioRender)) 
	//	LUA->ThrowError("[GWater2 Internal Error]: C++ Studiorender failed to load!");

	// Defined in 'shader_inject.h'
	if (!inject_shaders())
		LUA->ThrowError("[GWater2 Internal Error]: C++ Shadersystem failed to load!");

	// weird bsp filesystem
	if (FileSystem::LoadFileSystem() != FILESYSTEM_STATUS::OK)
		LUA->ThrowError("[GWater2 Internal Error]: C++ Filesystem failed to load!");
	
	FLEXSOLVER_METATABLE = LUA->CreateMetaTable("FlexSolver");
	ADD_FUNCTION(LUA, FLEXSOLVER_GarbageCollect, "__gc");	// FlexMetaTable.__gc = FlexGC

	// FlexMetaTable.__index = {func1, func2, ...}
	LUA->CreateTable();
	ADD_FUNCTION(LUA, FLEXSOLVER_GarbageCollect, "Destroy");
	ADD_FUNCTION(LUA, FLEXSOLVER_Tick, "Tick");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddParticle, "AddParticle");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddCube, "AddCube");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetParticles, "GetParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_RenderParticles, "RenderParticles");
	//ADD_FUNCTION(LUA, RenderParticlesExternal, "RenderPositionsExternal");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddConcaveMesh, "AddConcaveMesh");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddConvexMesh, "AddConvexMesh");
	ADD_FUNCTION(LUA, FLEXSOLVER_RemoveMesh, "RemoveMesh");
	ADD_FUNCTION(LUA, FLEXSOLVER_UpdateMesh, "UpdateMesh");
	ADD_FUNCTION(LUA, FLEXSOLVER_SetParameter, "SetParameter");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetParameter, "GetParameter");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetCount, "GetCount");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddMapMesh, "AddMapMesh");
	//ADD_FUNCTION(LUA, GetContacts, "GetContacts");
	ADD_FUNCTION(LUA, FLEXSOLVER_InitBounds, "InitBounds");
	ADD_FUNCTION(LUA, FLEXSOLVER_Reset, "Reset");
	LUA->SetField(-2, "__index");

	FLEXRENDERER_METATABLE = LUA->CreateMetaTable("FlexRenderer");
	ADD_FUNCTION(LUA, FLEXRENDERER_GarbageCollect, "__gc");	// FlexMetaTable.__gc = FlexGC

	// FlexMetaTable.__index = {func1, func2, ...}
	LUA->CreateTable();
	ADD_FUNCTION(LUA, FLEXRENDERER_GarbageCollect, "Destroy");
	ADD_FUNCTION(LUA, FLEXRENDERER_BuildIMeshes, "BuildIMeshes");
	ADD_FUNCTION(LUA, FLEXRENDERER_DrawIMeshes, "DrawIMeshes");
	LUA->SetField(-2, "__index");

	// _G.FlexSolver = NewFlexSolver
	LUA->PushSpecial(SPECIAL_GLOB);
	ADD_FUNCTION(LUA, NewFlexSolver, "FlexSolver");
	ADD_FUNCTION(LUA, NewFlexRenderer, "FlexRenderer");
	ADD_FUNCTION(LUA, IsMSAAEnabled, "IsMSAAEnabled");
	LUA->Pop();

	return 0;
}

// Called when the module is unloaded
GMOD_MODULE_CLOSE() {
	NvFlexShutdown(FLEX_LIBRARY);
	FLEX_LIBRARY = nullptr;

	// Defined in 'shader_inject.h'
	eject_shaders();

	return 0;
}