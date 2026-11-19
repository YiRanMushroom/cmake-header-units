# HeaderUnits.cmake -- C++20 header units with CMake (prototype).  See README.md.
#
#   include(HeaderUnits)          # top-level CMakeLists.txt, after project(), before add_subdirectory()
#
#   add_header_units(<set> HEADERS <name>... [LINK_LIBRARIES <target>...] [INCLUDE_DIRECTORIES <dir>...]
#                    [COMPILE_DEFINITIONS <def>...] [COMPILE_OPTIONS <opt>...]
#                    [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>] [POSITION_INDEPENDENT_CODE <bool>])
#   target_import_header_units(<target> <set> [SOURCES <src>...])
#   target_auto_header_units(<target> [LINK_LIBRARIES ...] [INCLUDE_DIRECTORIES ...] [COMPILE_DEFINITIONS ...]
#                            [COMPILE_OPTIONS ...] [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>] [EXCLUDE <name>...]
#                            [NO_RECONFIGURE])
#   target_header_units_scan_sources(<target> <src>... [same options as target_auto_header_units])
#   set(HU_ALLOW_HEADER_IMPORTS ON)   # experimental: header units whose headers import header units
#
# Toolchains:
#   GCC 16 (libstdc++), Clang 22 (clang++ with libstdc++ or the MSVC STL, clang-cl with the MSVC STL) and MSVC 19.40+
#   with the Ninja generator: the module builds the header units (HeaderUnits/GCC.cmake, Clang.cmake, MSVCNinja.cmake).
#   MSVC with a Visual Studio generator: MSBuild builds them; the commands do nothing (HeaderUnits/MSVC.cmake).
#
# Every place that relies on CMake internals or on undocumented CMake behaviour (unsupported, may break with any
# CMake release) is marked "CMAKE-INTERNAL" -- grep for it.

include_guard(GLOBAL)

if(NOT CMAKE_CXX_COMPILER_LOADED)
  message(FATAL_ERROR "HeaderUnits: include it after project() with the CXX language enabled.")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND CMAKE_GENERATOR MATCHES "^Visual Studio")
  if(CMAKE_VERSION VERSION_LESS 3.28)
    message(FATAL_ERROR "HeaderUnits: CMake >= 3.28 is required (C++20 module scanning with MSBuild).")
  endif()
  include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/MSVC.cmake")
  return()
endif()

if(CMAKE_VERSION VERSION_LESS 4.2)
  message(FATAL_ERROR "HeaderUnits: CMake >= 4.2 is required (OBJECT_NAME source property).")
endif()
if(NOT CMAKE_GENERATOR STREQUAL "Ninja")
  message(FATAL_ERROR "HeaderUnits: with GCC, Clang and MSVC only the single-config Ninja generator is supported (MSVC: also "
    "a Visual Studio generator) (found '${CMAKE_GENERATOR}').")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(_HU_TC GCC)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 16)
    message(WARNING "HeaderUnits: tested with GCC 16 only (found ${CMAKE_CXX_COMPILER_VERSION}).")
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_FRONTEND_VARIANT MATCHES "^(GNU|MSVC)$")
  set(_HU_TC Clang)          # clang++ and clang-cl (the MSVC-style driver) alike
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 22)
    message(WARNING "HeaderUnits: tested with Clang 22 only (found ${CMAKE_CXX_COMPILER_VERSION}).")
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  set(_HU_TC MSVC)
  if(MSVC_VERSION LESS 1940)
    message(FATAL_ERROR "HeaderUnits: with Ninja, MSVC 19.40 (Visual Studio 2022 17.10) or later is required (/ifcOnly); "
      "found ${CMAKE_CXX_COMPILER_VERSION}.")
  endif()
else()
  message(FATAL_ERROR "HeaderUnits: unsupported compiler '${CMAKE_CXX_COMPILER_ID}' "
    "(frontend '${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}'). Supported: GCC, Clang (clang++ or clang-cl) and MSVC with "
    "Ninja, and MSVC with a Visual Studio generator.")
endif()
set(_HU_DIR "${CMAKE_BINARY_DIR}/CMakeFiles/header_units")
set_property(GLOBAL PROPERTY _HU_TC "${_HU_TC}")
set_property(GLOBAL PROPERTY _HU_DIR "${_HU_DIR}")

# Spelled with CMAKE_CURRENT_LIST_DIR (not a variable of our own) so that IDEs which follow include() (CLion's CMake
# completion) find the commands defined in these files.
include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/Common.cmake")
if(_HU_TC STREQUAL "GCC")      # toolchain setup and strategy macros
  include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/GCC.cmake")
elseif(_HU_TC STREQUAL "MSVC")
  include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/MSVCNinja.cmake")
else()
  include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/Clang.cmake")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/Core.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/HeaderUnits/Auto.cmake")
