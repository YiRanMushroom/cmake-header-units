cmake_minimum_required(VERSION 3.28...4.5)
project(t26_shared_targets LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# One source in two targets that ask for different things: src/plain.cpp (#include <t26.h>) is compiled by t26_imp
# (directory a), which imports the set, and by t26_plain (directory c), which does not: t26_plain's compile stays
# textual and needs no header unit.
add_header_units(t26_set HEADERS t26.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/inc")
add_subdirectory(a)
add_subdirectory(c)

enable_testing()
add_test(NAME t26_imp COMMAND t26_imp)
add_test(NAME t26_plain COMMAND t26_plain)
