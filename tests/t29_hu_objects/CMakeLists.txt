cmake_minimum_required(VERSION 3.28...4.5)
project(t29_hu_objects LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_header_units(t29_hu HEADERS compare format string)

# Importers odr-use static data members that MSVC defines only in the header unit's object file
# (std::strong_ordering::less, ..., and <format>'s precision tables): a static library, an object library and the
# program itself import the header units, so each kind of consumer has to get that object linked.
add_library(t29_lib STATIC lib.cpp)
target_import_header_units(t29_lib t29_hu)
add_library(t29_obj OBJECT obj.cpp)
target_import_header_units(t29_obj t29_hu)
add_executable(t29 main.cpp)
target_import_header_units(t29 t29_hu)
target_link_libraries(t29 PRIVATE t29_lib t29_obj)

enable_testing()
add_test(NAME t29 COMMAND t29)
