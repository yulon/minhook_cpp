cmake_minimum_required(VERSION 3.1.3)

set(minhook_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/minhook")
file(GLOB_RECURSE minhook_SOURCES "${minhook_DIR}/src/*.cpp" "${minhook_DIR}/src/hde/*.cpp")
add_library(minhook STATIC ${minhook_SOURCES})
target_include_directories(minhook PUBLIC "${minhook_DIR}/include")
set_target_properties(minhook PROPERTIES C_STANDARD 11)

add_library(minhook_cpp INTERFACE IMPORTED)
target_include_directories(minhook_cpp INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(minhook_cpp INTERFACE minhook)
