cmake_minimum_required(VERSION 3.28...4.5)
project(t24_two_sets LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# One header in two sets of the same directory, each set imported by its own target.  <t24/val.h> is the same file in
# both sets, spelled differently (hu_two finds it as <val.h>).
add_header_units(hu_one HEADERS vector t24/val.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/include")
add_header_units(hu_two HEADERS vector val.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/include/t24")

add_executable(t24_a a.cpp)
target_include_directories(t24_a PRIVATE include)
target_import_header_units(t24_a hu_one)
add_executable(t24_b b.cpp)
target_include_directories(t24_b PRIVATE include/t24)
target_import_header_units(t24_b hu_two)

enable_testing()
add_test(NAME t24_a COMMAND t24_a)
add_test(NAME t24_b COMMAND t24_b)
