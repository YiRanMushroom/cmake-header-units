cmake_minimum_required(VERSION 3.28...4.5)
project(t09_header_import_error LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)
# inc/bad.h contains "import <vector>;" -> must be rejected at configure time (HU_ALLOW_HEADER_IMPORTS is OFF).
add_executable(t09 main.cpp)
target_include_directories(t09 PRIVATE inc)
target_auto_header_units(t09)
