cmake_minimum_required(VERSION 3.28...4.5)
project(t10_header_imports LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)
set(HU_ALLOW_HEADER_IMPORTS ON)   # experimental: headers may import header units

# (a) auto: main.cpp imports <proj/a.h>; a.h imports <vector> and "b.h" -> discovered recursively.
# T10_INC_COPY: the test driver builds against a private copy of inc/ so that touching b.h cannot disturb a
# parallel run of another toolchain on the same source tree.
set(T10_INC "${CMAKE_CURRENT_SOURCE_DIR}/inc")
if(T10_INC_COPY)
  if(NOT EXISTS "${T10_INC_COPY}/proj/a.h")
    file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/inc/" DESTINATION "${T10_INC_COPY}")
  endif()
  set(T10_INC "${T10_INC_COPY}")
endif()
add_executable(t10 main.cpp macro_probe.cpp)
target_include_directories(t10 PRIVATE ${T10_INC})
target_auto_header_units(t10)

# (b) manual set with an intra-set import (c.h imports "d.h") and a cross-set import (<vector>, from t10's sets).
add_header_units(hu_m HEADERS proj2/c.h proj2/d.h INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/inc2)
add_executable(t10m main_m.cpp)
target_include_directories(t10m PRIVATE inc2)
target_import_header_units(t10m hu_m)

enable_testing()
add_test(NAME t10 COMMAND t10)
add_test(NAME t10m COMMAND t10m)
