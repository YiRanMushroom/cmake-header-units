cmake_minimum_required(VERSION 3.28...4.5)
project(t20_wrong_file LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# The set builds dirA/a.h; the consumer's own include path finds dirB/a.h first, which has no header unit: its
# import <a.h> would fail to compile.  Configure warns, naming both files.
add_header_units(t20_set HEADERS a.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/dirA")
add_executable(t20 main.cpp)
target_include_directories(t20 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/dirB" "${CMAKE_CURRENT_SOURCE_DIR}/dirA")
target_import_header_units(t20 t20_set)
