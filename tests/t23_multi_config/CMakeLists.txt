cmake_minimum_required(VERSION 3.28...4.5)
project(t23_multi_config LANGUAGES CXX)
# Ninja Multi-Config: a BMI per configuration, each built with that configuration's flags (NDEBUG in Release).
set(CMAKE_CXX_STANDARD 20)
# A Release-only include directory (CMAKE_CXX_FLAGS_RELEASE comes after the target's -I): its cfgval.h is never the one
# found, so the configurations agree.  T23_SHADOW: one whose <vector> shadows the C++ library's in Release only.
string(APPEND CMAKE_CXX_FLAGS_RELEASE " -I${CMAKE_CURRENT_SOURCE_DIR}/relinc")
if(T23_SHADOW)
  string(APPEND CMAKE_CXX_FLAGS_RELEASE " -I${CMAKE_CURRENT_SOURCE_DIR}/relshadow")
endif()
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_executable(t23 main.cpp other.cpp)
target_include_directories(t23 PRIVATE inc)
target_compile_definitions(t23 PRIVATE "T23_EXPECT=$<IF:$<CONFIG:Release>,2,1>")
target_auto_header_units(t23)

enable_testing()
add_test(NAME t23 COMMAND t23)
