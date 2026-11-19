cmake_minimum_required(VERSION 3.28...4.5)
project(t28_cxx_sources LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# A target's C++ sources are those CMake compiles as C++.  Each source below is the only importer of its header, so a
# source that is not scanned, or does not get the header units, fails the build:
#   m28.cppm  in the default CXX_MODULES file set;
#   gen.cpp   a configure_file output in the build directory, listed by a relative path;
#   lang.c    LANGUAGE CXX;
#   hfo.cpp   HEADER_FILE_ONLY: not compiled, so not scanned (its <t28_bad.h> does not compile);
#   gx.cpp (a source of the Debug configuration) and $<TARGET_OBJECTS:t28_obj>: generator expressions, evaluated at
#             generate time; the module does not see them (gx.cpp's #include stays textual).
# t28s: target_header_units_scan_sources() of gen_s.cpp, a configure_file output listed by a relative path.
# t28i: target_import_header_units(... SOURCES gen_i.cpp), the same kind of source.
configure_file(gen.cpp.in gen.cpp COPYONLY)
configure_file(gen_s.cpp.in gen_s.cpp COPYONLY)
configure_file(gen_i.cpp.in gen_i.cpp COPYONLY)
add_library(t28_obj OBJECT obj.cpp)

add_executable(t28 main.cpp gen.cpp lang.c hfo.cpp "$<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/gx.cpp>"
  $<TARGET_OBJECTS:t28_obj>)
target_sources(t28 PRIVATE FILE_SET CXX_MODULES FILES m28.cppm)
set_source_files_properties(lang.c PROPERTIES LANGUAGE CXX)
set_source_files_properties(hfo.cpp PROPERTIES HEADER_FILE_ONLY ON)
target_include_directories(t28 PRIVATE inc)
target_auto_header_units(t28)

add_executable(t28s s.cpp gen_s.cpp $<TARGET_OBJECTS:t28_obj>)
target_include_directories(t28s PRIVATE inc)
target_header_units_scan_sources(t28s gen_s.cpp)

add_header_units(t28_imp HEADERS t28_imp.h INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/inc)
add_executable(t28i i.cpp gen_i.cpp)
target_include_directories(t28i PRIVATE inc)
target_import_header_units(t28i t28_imp SOURCES gen_i.cpp)

enable_testing()
add_test(NAME t28 COMMAND t28)
add_test(NAME t28s COMMAND t28s)
add_test(NAME t28i COMMAND t28i)
