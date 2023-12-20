#pragma once
#include "GWaterNormals.h"
#include "GWaterSmooth.h"
#include "IShaderSystem.h"

// all of these externals MUST be defined (NOT NULL) BEFORE inserting shaders into the materialsystem or you WILL crash!
extern const MaterialSystem_Config_t* g_pConfig = NULL;
extern IMaterialSystemHardwareConfig* g_pHardwareConfig = NULL;
extern IShaderSystem* g_pSLShaderSystem;
//extern IVEngineClient* engine = NULL;

CShaderSystem::ShaderDLLInfo_t* g_pShaderLibDLL;	// our shader directory
CShaderSystem* g_pCShaderSystem;
//int m_ShaderDLLs_index;		// index in materialsystem of our added shader directory (unused)

// returns true if successful, false otherwise
bool inject_shaders() {
	// Load source system variables for personal use
	if (!Sys_LoadInterface("materialsystem", "ShaderSystem002", NULL, (void**)&g_pSLShaderSystem)) return false;
	if (!Sys_LoadInterface("materialsystem", "VMaterialSystemConfig002", NULL, (void**)&g_pConfig)) return false;
	if (!Sys_LoadInterface("materialsystem", "MaterialSystemHardwareConfig012", NULL, (void**)&g_pHardwareConfig)) return false;

	// imagine not being able to run dx9
	if (g_pHardwareConfig->GetDXSupportLevel() < 90) return false;
	// ^this check isnt technically required, but I only compiled my shaders for dx9 and above
	
	g_pCShaderSystem = (CShaderSystem*)g_pSLShaderSystem;
	
	// Create new shader directory (dll?)
	//m_ShaderDLLs_index = g_pCShaderSystem->m_ShaderDLLs.AddToTail();	// WARNING: Adding more than 1 shader dll crashes the game!!!
	
	// if the above code is uncommented, m_ShaderDLLs_index ends up being equal to 7
	// im not sure what indexes 0-6 actually mean in terms of the gmod source code but ive found 0 to be the most stable
	// in theory you could have an infinite amount of shaders on this index, you just need to make sure to remove them on unload
	g_pShaderLibDLL = &g_pCShaderSystem->m_ShaderDLLs[0];

	//g_pShaderLibDLL->m_pFileName = strdup("gwater_shaders.dll");
	//g_pShaderLibDLL->m_bModShaderDLL = true;

	// Insert our shader into the materialsystem
	// you need the COMPILED .vcs shaders in GarrysMod/garrysmod/shaders/fxc for the shaders to appear ingame!
	g_pShaderLibDLL->m_ShaderDict.Insert(GWaterNormals::s_Name, &GWaterNormals::s_ShaderInstance);
	g_pShaderLibDLL->m_ShaderDict.Insert(GWaterSmooth::s_Name, &GWaterSmooth::s_ShaderInstance);

	return true;
}

bool eject_shaders() {
	// Dont forget to free shaders or you crash on reload!
	if (g_pShaderLibDLL) {
		// Remove inserted shader(s)
		g_pShaderLibDLL->m_ShaderDict.Remove(GWaterNormals::s_Name);
		g_pShaderLibDLL->m_ShaderDict.Remove(GWaterSmooth::s_Name);

		// Remove our added shader directory (dll?) in material system
		//g_pCShaderSystem->m_ShaderDLLs.Remove(m_ShaderDLLs_index);

		return true;
	}

	return false;
}
