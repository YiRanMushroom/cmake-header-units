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
#   set(HU_ALLOW_HEADER_IMPORTS ON)   # experimental: header units whose headers import header units
#
# Toolchains:
#   GCC 16 (libstdc++) and Clang 22 (GNU-style driver; libstdc++ or the MSVC STL) with the Ninja generator: the
#   module builds the header units (HeaderUnits/GCC.cmake, HeaderUnits/Clang.cmake).
#   MSVC with a Visual Studio generator: MSBuild builds them; the commands do nothing (HeaderUnits/MSVC.cmake).
#
# Every place that relies on CMake internals or on undocumented CMake behaviour (unsupported, may break with any
# CMake release) is marked "CMAKE-INTERNAL" -- grep for it.

include_guard(GLOBAL)

if(NOT CMAKE_CXX_COMPILER_LOADED)
  message(FATAL_ERROR "HeaderUnits: include it after project() with the CXX language enabled.")
endif()
set(_HU_MODULE_DIR "${CMAKE_CURRENT_LIST_DIR}/HeaderUnits")

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  if(CMAKE_VERSION VERSION_LESS 3.28)
    message(FATAL_ERROR "HeaderUnits: CMake >= 3.28 is required (C++20 module scanning with MSBuild).")
  endif()
  include("${_HU_MODULE_DIR}/MSVC.cmake")
  return()
endif()

if(CMAKE_VERSION VERSION_LESS 4.2)
  message(FATAL_ERROR "HeaderUnits: CMake >= 4.2 is required (OBJECT_NAME source property).")
endif()
if(NOT CMAKE_GENERATOR STREQUAL "Ninja")
  message(FATAL_ERROR "HeaderUnits: with GCC and Clang only the single-config Ninja generator is supported (found '${CMAKE_GENERATOR}').")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(_HU_TC GCC)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 16)
    message(WARNING "HeaderUnits: tested with GCC 16 only (found ${CMAKE_CXX_COMPILER_VERSION}).")
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "GNU")
  set(_HU_TC Clang)
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 22)
    message(WARNING "HeaderUnits: tested with Clang 22 only (found ${CMAKE_CXX_COMPILER_VERSION}).")
  endif()
else()
  message(FATAL_ERROR "HeaderUnits: unsupported compiler '${CMAKE_CXX_COMPILER_ID}' "
    "(frontend '${CMAKE_CXX_COMPILER_FRONTEND_VARIANT}'). Supported: GCC, and Clang with the GNU-style driver "
    "(clang++, not clang-cl), both with Ninja, and MSVC with a Visual Studio generator. clang-cl is not supported.")
endif()
set(_HU_DIR "${CMAKE_BINARY_DIR}/CMakeFiles/header_units")
set_property(GLOBAL PROPERTY _HU_TC "${_HU_TC}")
set_property(GLOBAL PROPERTY _HU_DIR "${_HU_DIR}")

include("${_HU_MODULE_DIR}/Common.cmake")
include("${_HU_MODULE_DIR}/${_HU_TC}.cmake")     # GCC.cmake or Clang.cmake: toolchain setup and strategy macros
include("${_HU_MODULE_DIR}/Core.cmake")
include("${_HU_MODULE_DIR}/Auto.cmake")
