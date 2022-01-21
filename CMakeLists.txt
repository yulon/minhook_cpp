cmake_minimum_required(VERSION 3.0)

project(minhook_cpp)

include("cmake/DepPull.cmake")

deppull(
	minhook
	GIT_REPO "https://github.com/TsudaKageyu/minhook.git"
)

add_library(minhook_cpp INTERFACE)
set(minhook_cpp_INCLUDE_DIR "include")
target_include_directories(minhook_cpp INTERFACE ${minhook_cpp_INCLUDE_DIR})
target_link_libraries(minhook_cpp INTERFACE minhook)
