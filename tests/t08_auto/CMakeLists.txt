cmake_minimum_required(VERSION 3.28...4.5)
project(t08_auto LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)
include(../common/ExternalLibs.cmake)

add_library(mylib STATIC lib/src/mylib.cpp)
target_include_directories(mylib PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/include>)

# No header lists anywhere: the imports in the sources decide.
add_executable(t08 app/main.cpp app/sub/other.cpp)
target_link_libraries(t08 PRIVATE mylib fmt::fmt)
target_auto_header_units(t08)

# A second target: <vector> is reused from t08's set, <string> gets a new set.
add_executable(t08b app/second.cpp)
target_auto_header_units(t08b)

enable_testing()
add_test(NAME t08 COMMAND t08)
add_test(NAME t08b COMMAND t08b)
