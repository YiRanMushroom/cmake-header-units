cmake_minimum_required(VERSION 3.28...4.5)
project(t14_textual_pragma LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# main.cpp imports the stb-style single-header library; impl.cpp carries "HeaderUnits pragma: textual-includes"
# and includes it textually with STBISH_IMPLEMENTATION (translated into an import, the definition would be lost).
add_executable(t14 main.cpp impl.cpp plain.cpp)
target_include_directories(t14 PRIVATE inc)
target_auto_header_units(t14)

enable_testing()
add_test(NAME t14 COMMAND t14)
