cmake_minimum_required(VERSION 3.28...4.5)
project(t27_module_two_targets LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_header_units(t27_hu HEADERS vector)

# One module interface source compiled by two targets of this directory (source properties are per directory), each
# imported by a program that has no header units of its own: both programs need the module's header units.
enable_testing()
foreach(n a b)
  add_library(t27_m_${n} STATIC)
  target_sources(t27_m_${n} PUBLIC FILE_SET CXX_MODULES FILES m.cppm)
  target_import_header_units(t27_m_${n} t27_hu)
  add_executable(t27_${n} main.cpp)
  target_link_libraries(t27_${n} PRIVATE t27_m_${n})
  add_test(NAME t27_${n} COMMAND t27_${n})
endforeach()
