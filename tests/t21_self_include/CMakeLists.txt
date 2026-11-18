cmake_minimum_required(VERSION 3.28...4.5)
project(t21_self_include LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# selfinc.h includes selfinc_core.h, which includes "selfinc.h" again (as fmt's core.h includes "format.h"): while
# the header unit of selfinc.h is built, that nested #include names the header unit being built.  The value comes from
# a file the test rewrites between builds (T21_VALUE in value.h).
add_executable(t21 main.cpp)
target_include_directories(t21 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include" "${T21_VALUE_DIR}")
target_auto_header_units(t21)
enable_testing()
add_test(NAME t21 COMMAND t21)
