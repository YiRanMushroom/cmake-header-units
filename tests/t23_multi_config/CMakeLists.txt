cmake_minimum_required(VERSION 3.28...4.5)
project(t23_multi_config LANGUAGES CXX)
# Ninja Multi-Config: a BMI per configuration, each built with that configuration's flags (NDEBUG in Release).
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_executable(t23 main.cpp other.cpp)
target_include_directories(t23 PRIVATE inc)
target_compile_definitions(t23 PRIVATE "T23_EXPECT=$<IF:$<CONFIG:Release>,2,1>")
target_auto_header_units(t23)

enable_testing()
add_test(NAME t23 COMMAND t23)
