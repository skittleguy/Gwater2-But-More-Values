PROJECT_GENERATOR_VERSION = 3	-- 3 = 64 bit support

newoption({
	trigger = "gmcommon",
	description = "Sets the path to the garrysmod_common (https://github.com/danielga/garrysmod_common) directory",
	value = "./garrysmod_common",
	default = "./garrysmod_common"
})

local gmcommon = assert(_OPTIONS.gmcommon or os.getenv("GARRYSMOD_COMMON"),
	"you didn't provide a path to your garrysmod_common (https://github.com/danielga/garrysmod_common) directory")

include(gmcommon)

CreateWorkspace({name = "gwater2", abi_compatible = true, path = ""})
	--CreateProject({serverside = true, source_path = "source", manual_files = false})
	--	IncludeLuaShared()
	--	IncludeScanning()
	--	IncludeDetouring()
	--	IncludeSDKCommon()
	--	IncludeSDKTier0()
	--	IncludeSDKTier1()

	CreateProject({serverside = false, source_path = "src"})
		--IncludeLuaShared()
		--IncludeScanning()
		--IncludeDetouring()
		IncludeSDKCommon()
		IncludeSDKTier0()
		IncludeSDKTier1()
		IncludeSDKMathlib()

		includedirs {
			"FleX/include",
			"BSPParser",
			"GMFS",
			"src/sourceengine",
			"cpp-httplib"
		}

		files {
			"BSPParser/**",
			"GMFS/**",
			"src/sourceengine/*",
			"src/shaders/*"
		}

		filter({"system:windows", "platforms:x86"})
			targetsuffix("_win32")
			includedirs {
				"openssl/x86/include"
			}
			libdirs {
				"FleX/lib/win32",
				"openssl/x86/lib"
			}
			links { 
				"NvFlexReleaseD3D_x86",
				"NvFlexDeviceRelease_x86",
				"NvFlexExtReleaseD3D_x86",
				"libcrypto",
				"libssl"
			}

		filter({"system:windows", "platforms:x86_64"})
			targetsuffix("_win64")
			includedirs {
				"openssl/x64/include"
			}
			libdirs {
				"FleX/lib/win64",
				"openssl/x64/lib"
			}
			links { 
				"NvFlexReleaseD3D_x64",
				"NvFlexDeviceRelease_x64",
				"NvFlexExtReleaseD3D_x64",
				"libcrypto",
				"libssl"
			}
			
		filter({"system:linux", "platforms:x86_64"})
			targetsuffix("_linux64")
			libdirs {
				"FleX/lib/linux64"
			}
			links { 
				"FleX/lib/linux64/NvFlexReleaseCUDA_x64.a",
				"FleX/lib/linux64/NvFlexDeviceRelease_x64.a",
				"FleX/lib/linux64/NvFlexExtReleaseCUDA_x64.a"
			}
