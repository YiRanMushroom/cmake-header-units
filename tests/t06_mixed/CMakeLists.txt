cmake_minimum_required(VERSION 3.28...4.5)
project(t06_mixed LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_header_units(hu_vec HEADERS vector)

add_executable(t06 mixed.cpp excluded.cpp)
target_import_header_units(t06 hu_vec SOURCES mixed.cpp)   # excluded.cpp: no header units

# Boundary probes: each TU gets the <vector> header unit; built one by one by the driver.
foreach(p import_then_include include_then_import cstdio_then_import loaded_not_imported
          import_then_include_same include_same_then_import)
  add_library(p_${p} OBJECT EXCLUDE_FROM_ALL probes/${p}.cpp)
  target_import_header_units(p_${p} hu_vec)
endforeach()

enable_testing()
add_test(NAME t06 COMMAND t06)
