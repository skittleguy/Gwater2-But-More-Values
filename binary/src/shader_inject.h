#pragma once
#include "GWaterNormals.h"
#include "IShaderSystem.h"
#include "cdll_client_int.h"

// these externals MUST be defined (NOT NULL) BEFORE inserting shaders into the materialsystem or you WILL crash!
extern const MaterialSystem_Config_t* g_pConfig = NULL;
extern IMaterialSystemHardwareConfig* g_pHardwareConfig = NULL;
//extern IVEngineClient* engine = NULL;
extern IShaderSystem* g_pSLShaderSystem;
extern IMaterialSystem* g_pMaterialSystem;

CShaderSystem::ShaderDLLInfo_t* g_pShaderLibDLL;	// our shader directory
CShaderSystem* g_pCShaderSystem;
int m_ShaderDLLs_index;								// index in materialsystem of our added shader directory

// returns true if successful, false otherwise
bool detour_shaders() {
	// Load material system variables for personal use
	if (!Sys_LoadInterface("materialsystem", "ShaderSystem002", NULL, (void**)&g_pSLShaderSystem)) return false;
	if (!Sys_LoadInterface("materialsystem", "VMaterialSystemConfig002", NULL, (void**)&g_pConfig)) return false;
	if (!Sys_LoadInterface("materialsystem", "MaterialSystemHardwareConfig012", NULL, (void**)&g_pHardwareConfig)) return false;
	if (!Sys_LoadInterface("materialsystem", MATERIAL_SYSTEM_INTERFACE_VERSION, NULL, (void**)&g_pMaterialSystem)) return false;

	// lmao imagine not being able to run dx9
	if (g_pHardwareConfig->GetDXSupportLevel() < 90) return false;

	// Create new shader directory (dll?)
	g_pCShaderSystem = (CShaderSystem*)g_pSLShaderSystem;
	m_ShaderDLLs_index = g_pCShaderSystem->m_ShaderDLLs.AddToTail();
	g_pShaderLibDLL = &g_pCShaderSystem->m_ShaderDLLs[m_ShaderDLLs_index];
	g_pShaderLibDLL->m_pFileName = strdup("gwater_shaders.dll");
	g_pShaderLibDLL->m_bModShaderDLL = true;

	// Insert our shader into the materialsystem
	g_pShaderLibDLL->m_ShaderDict.Insert(GWaterNormals::s_Name, &GWaterNormals::s_ShaderInstance);

	return true;
}

bool undetour_shaders() {
	// Dont forget to free shaders or you crash on reload!
	if (g_pShaderLibDLL) {
		// Remove all inserted shaders
		g_pShaderLibDLL->m_ShaderDict.RemoveAll();

		// Remove our added shader directory (dll?) in material system
		g_pCShaderSystem->m_ShaderDLLs.Remove(m_ShaderDLLs_index);

		return true;
	}

	return false;
}
