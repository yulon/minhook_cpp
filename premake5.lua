workspace "minhook_cpp"
	location ( "build" )
	objdir("build/obj")

	dofileopt "include.pm5"

	platforms { "x64" }
	configurations { "Debug", "Release" }

	configuration "Debug"
		targetsuffix "_d"
		defines { "DEBUG" }
		symbols "On"
		warnings "Extra"

	configuration "Release"
		defines { "NDEBUG" }
		optimize "Speed"

	configuration { "not StaticLib" }
		targetdir("bin")

	configuration { "StaticLib" }
		targetdir("lib")

	configuration { "windows", "gmake*", "StaticLib" }
		targetprefix "lib"
		targetextension ".a"

	dofileopt "project.pm5"
