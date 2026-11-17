cmake_minimum_required(VERSION 3.28...4.5)
project(t03_named_modules LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_header_units(hu_std HEADERS vector string iostream)

add_library(m STATIC)
target_sources(m PUBLIC FILE_SET CXX_MODULES FILES m.cppm)
target_import_header_units(m hu_std)

add_executable(t03 main.cpp)
target_link_libraries(t03 PRIVATE m)
target_import_header_units(t03 hu_std)

# Another target importing m (cross-target): no header units of its own.
add_executable(t03_other other.cpp)
target_link_libraries(t03_other PRIVATE m)

# Boundary probe (built only by the driver): non-exported header-unit import inside a module interface.
add_library(p_m2 STATIC EXCLUDE_FROM_ALL)
target_sources(p_m2 PUBLIC FILE_SET CXX_MODULES FILES m2.cppm)
target_import_header_units(p_m2 hu_std)
add_executable(p_m2_consumer EXCLUDE_FROM_ALL m2_consumer.cpp)
target_link_libraries(p_m2_consumer PRIVATE p_m2)

# Kitware #28166 probe (driver configures a second tree with -DT03_SYNTH=ON): a cross-target importer of m
# with its own target-level compile options, which makes CMake synthesize a separate BMI of m for it.
option(T03_SYNTH "add a cross-target importer of m with target-level compile options" OFF)
if(T03_SYNTH)
  add_executable(t03_synth other.cpp)
  target_link_libraries(t03_synth PRIVATE m)
  set(T03_SYNTH_OPTIONS "-Wall" CACHE STRING "target-level options of t03_synth")
  target_compile_definitions(t03_synth PRIVATE T03_SYNTH_DEFINE=1)
  target_compile_options(t03_synth PRIVATE ${T03_SYNTH_OPTIONS})
endif()

enable_testing()
add_test(NAME t03 COMMAND t03)
add_test(NAME t03_other COMMAND t03_other)
