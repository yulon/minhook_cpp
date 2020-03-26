cmake_minimum_required(VERSION 3.0)

project(minhook_cpp)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/DepPull.cmake")

DepPull(
	minhook
	GIT_REPO "https://github.com/TsudaKageyu/minhook.git"
)
file(GLOB_RECURSE minhook_SRC "${DEPPULL_minhook_SOURCE_DIR}/src/*.c")
add_library(minhook STATIC ${minhook_SRC})
set(minhook_INCLUDE_DIRS "${DEPPULL_minhook_SOURCE_DIR}/include")
target_include_directories(minhook INTERFACE ${minhook_INCLUDE_DIRS})
set_target_properties(minhook PROPERTIES C_STANDARD 11)

add_library(minhook_cpp INTERFACE IMPORTED)
set(minhook_cpp_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(minhook_cpp INTERFACE ${minhook_cpp_INCLUDE_DIR})
target_link_libraries(minhook_cpp INTERFACE minhook)
