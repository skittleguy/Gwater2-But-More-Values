#include <windows.h>	// GetModuleHandle
#include <Psapi.h>

bool Compare(const BYTE* pData, const BYTE* bMask, const char* szMask) {
	for (; *szMask; ++szMask, ++pData, ++bMask) {
		if (*szMask == 'x' && *pData != *bMask) {
			return false;
		}
	}
	return (*szMask) == NULL;
}

BYTE* FindPattern(BYTE* dwAddress, SIZE_T dwSize, BYTE* pbSig, const char* szMask) {
	SIZE_T length = strlen(szMask);
	for (SIZE_T i = 0; i < dwSize - length; i++) {
		if (Compare(dwAddress + i, pbSig, szMask)) {
			return dwAddress + i;
		}
	}
	return nullptr;
}

BYTE* Scan(const char* moduleName, const char* signature) {
	HMODULE hModule = GetModuleHandleA(moduleName);
	if (!hModule) {
		return nullptr;
	}

	MODULEINFO modInfo;
	if (!GetModuleInformation(GetCurrentProcess(), hModule, &modInfo, sizeof(MODULEINFO))) {
		return nullptr;
	}

	BYTE* pbSig = new BYTE[strlen(signature) / 2];
	char* szMask = new char[strlen(signature) / 2 + 1];
	SIZE_T j = 0;

	for (SIZE_T i = 0; i < strlen(signature); i += 3) {
		if (signature[i] == '?') {
			pbSig[j] = 0;
			szMask[j] = '?';
		}
		else {
			pbSig[j] = (BYTE)strtol(&signature[i], NULL, 16);
			szMask[j] = 'x';
		}
		j++;
	}
	szMask[j] = '\0';

	BYTE* result = FindPattern((BYTE*)modInfo.lpBaseOfDll, modInfo.SizeOfImage, pbSig, szMask);

	delete[] pbSig;
	delete[] szMask;

	return result;
}