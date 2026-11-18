cmake_minimum_required(VERSION 3.28...4.5)
project(t19_scale LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# T19_N targets, each with its own include directory and header (so each gets its own set) plus <vector>.  The
# number of compiler runs for the header lookup must not depend on T19_N.  The sources live next to the build tree
# (not inside it: a header in the build tree takes another path on GCC).
if(NOT T19_N)
  set(T19_N 5)
endif()
set(gen "${CMAKE_BINARY_DIR}-gen")
foreach(i RANGE 1 ${T19_N})
  file(CONFIGURE OUTPUT "${gen}/inc${i}/h${i}.h" CONTENT "#pragma once\ninline int h${i}() { return ${i}; }\n")
  file(CONFIGURE OUTPUT "${gen}/m${i}.cpp" CONTENT
    "import <h${i}.h>;\nimport <vector>;\nint main() { std::vector<int> v{h${i}()}; return v[0] == ${i} ? 0 : 1; }\n")
  add_executable(t19_${i} "${gen}/m${i}.cpp")
  target_include_directories(t19_${i} PRIVATE "${gen}/inc${i}")
  target_auto_header_units(t19_${i})
endforeach()
