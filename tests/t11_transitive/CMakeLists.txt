cmake_minimum_required(VERSION 3.28...4.5)
project(t11_transitive LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)
include(../common/ExternalLibs.cmake)

# core: in-tree INTERFACE library (include dir + definition) that depends on an IMPORTED target (fmt::fmt).
add_library(core INTERFACE)
target_include_directories(core INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/core/include>)
target_compile_definitions(core INTERFACE CORE_LEVEL=7)
target_link_libraries(core INTERFACE fmt::fmt)
add_library(proj::core ALIAS core)

# privdep: linked PRIVATE by the static mylib -> $<LINK_ONLY:privdep>; must NOT reach mylib's header unit.
add_library(privdep INTERFACE)
target_compile_definitions(privdep INTERFACE PRIVDEP_LEAK=1)

# mylib: its public header includes <core/types.h> (a dependency's header) and needs EXTRA_ON (below).
add_library(mylib STATIC lib/src/mylib.cpp)
target_include_directories(mylib PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/include>)
target_link_libraries(mylib PUBLIC proj::core PRIVATE privdep)
target_compile_definitions(mylib PRIVATE MYLIB_BUILDING)   # mylib's own sources do see privdep
add_subdirectory(extra)   # links extra_defs into mylib from another directory (::@ markers)

# Manual set: only mylib is named; core, fmt::fmt and extra_defs come through mylib's link interface.
add_header_units(hu_my HEADERS mylib/api.h LINK_LIBRARIES mylib)
add_executable(t11 main.cpp)
target_link_libraries(t11 PRIVATE mylib)
target_import_header_units(t11 hu_my)

# Auto: the target links the ALIAS proj::core and imports <core/types.h>.
add_executable(t11b main_b.cpp)
target_link_libraries(t11b PRIVATE proj::core)
target_auto_header_units(t11b)

enable_testing()
add_test(NAME t11 COMMAND t11)
add_test(NAME t11b COMMAND t11b)
