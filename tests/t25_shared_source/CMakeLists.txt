cmake_minimum_required(VERSION 3.28...4.5)
project(t25_shared_source LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# One source (src/main.cpp) compiled by three targets that import the same set, each spelling its include directory
# differently: ta (directory a) "a/../inc", tb and tc (both in directory b) "b/../inc" and "b/../b/../inc".  GCC names
# a header unit by the spelling, so every compile of the source must find its own spelling in the map it gets.
add_header_units(t25_set HEADERS sh.h sh2.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/inc")
add_subdirectory(a)
add_subdirectory(b)

enable_testing()
add_test(NAME ta COMMAND ta)
add_test(NAME tb COMMAND tb)
add_test(NAME tc COMMAND tc)
