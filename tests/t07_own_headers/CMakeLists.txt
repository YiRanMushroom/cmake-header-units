cmake_minimum_required(VERSION 3.28...4.5)
project(t07_own_headers LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# The project's own library (in-tree, NOT imported); its public header becomes a header unit.
add_library(mylib STATIC lib/src/mylib.cpp)
target_include_directories(mylib PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/include>)

add_header_units(hu_std   HEADERS vector string)
add_header_units(hu_own   HEADERS mylib/api.h LINK_LIBRARIES mylib)
# A header next to the sources, used as "local.h" / "../local.h" (found relative to the including file).
add_header_units(hu_local HEADERS local.h INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/app)

add_executable(t07 app/main.cpp app/sub/other.cpp)
target_link_libraries(t07 PRIVATE mylib)
target_import_header_units(t07 hu_std)
target_import_header_units(t07 hu_own)
target_import_header_units(t07 hu_local)

enable_testing()
add_test(NAME t07 COMMAND t07)
