cmake_minimum_required(VERSION 3.28...4.5)
project(t13_same_name LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# Two targets whose <config.h> are different files; both also import <vector> (the same file).
add_subdirectory(a)
add_subdirectory(b)

enable_testing()
add_test(NAME ta COMMAND ta)
add_test(NAME tb COMMAND tb)
