cmake_minimum_required(VERSION 3.28...4.5)
project(a01_cmdline LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake")
include(HeaderUnits)

# Trivial vendored headers (outside the build tree) so that the PCMs build instantly; only the number of
# -fmodule-file=<abs pcm> options matters.  A01_STL=ON uses real MSVC STL headers instead.
set(A01_N 60 CACHE STRING "number of trivial headers in the set")
option(A01_STL "use the C++20 standard library headers instead of trivial ones" OFF)
if(A01_STL)
  set(hdrs algorithm any array atomic barrier bit bitset charconv chrono compare complex concepts
      condition_variable coroutine deque exception filesystem format forward_list fstream functional future
      initializer_list iomanip ios iosfwd iostream istream iterator latch limits list locale map memory
      memory_resource mutex new numbers numeric optional ostream queue random ranges ratio regex
      scoped_allocator semaphore set shared_mutex source_location span sstream stack stdexcept stop_token
      streambuf string string_view syncstream system_error thread tuple type_traits typeindex typeinfo
      unordered_map unordered_set utility valarray variant vector version)
  add_header_units(hu_many HEADERS ${hdrs})
  add_executable(a01 main_stl.cpp)
else()
  set(gen "${CMAKE_BINARY_DIR}-vendor/include")
  set(hdrs)
  math(EXPR last "${A01_N} - 1")
  foreach(i RANGE ${last})
    file(CONFIGURE OUTPUT "${gen}/many/h${i}.hpp" CONTENT "#pragma once\ninline int many_${i}() { return ${i}; }\n")
    list(APPEND hdrs many/h${i}.hpp)
  endforeach()
  add_library(many::many INTERFACE IMPORTED)
  set_target_properties(many::many PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${gen}")
  add_header_units(hu_many HEADERS ${hdrs} LINK_LIBRARIES many::many)
  add_executable(a01 main.cpp)
  target_link_libraries(a01 PRIVATE many::many)
endif()
target_import_header_units(a01 hu_many)
