cmake_minimum_required(VERSION 3.30...4.5)
project(t22_import_std LANGUAGES CXX)
# import std (CMake's own support, CMAKE_CXX_MODULE_STD) together with header units in the same TUs.
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_MODULE_STD ON)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_executable(t22 main.cpp other.cpp)
target_include_directories(t22 PRIVATE inc)
target_auto_header_units(t22)

enable_testing()
add_test(NAME t22 COMMAND t22)
