cmake_minimum_required(VERSION 3.28...4.5)
project(t01_stl LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_header_units(hu_std HEADERS vector string iostream)

add_executable(t01 main.cpp)
target_import_header_units(t01 hu_std)

enable_testing()
add_test(NAME t01 COMMAND t01)
