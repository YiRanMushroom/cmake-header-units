cmake_minimum_required(VERSION 3.28...4.5)
project(a04_runtime LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake")
include(HeaderUnits)

add_header_units(hu_vec HEADERS vector)
foreach(t a04_ok a04_rt a04_idl a04_gdbg)
  add_executable(${t} imp.cpp txt.cpp main.cpp)
  target_import_header_units(${t} hu_vec SOURCES imp.cpp)
endforeach()
set_target_properties(a04_rt PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreaded)   # static release CRT in a Debug build
target_compile_definitions(a04_idl PRIVATE _ITERATOR_DEBUG_LEVEL=0)
target_compile_definitions(a04_gdbg PRIVATE _GLIBCXX_DEBUG)            # libstdc++ analogue (port; no effect on MSVC STL)
