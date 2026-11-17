# HeaderUnits/MSVC.cmake -- MSVC with a Visual Studio generator: MSBuild scans the sources and builds the header units
# of "import <x>;" / "import \"x\";" itself (CMake marks C++20 sources for scanning).  The HeaderUnits commands are
# accepted, checked and otherwise do nothing, except keeping module scanning on for their targets, so the same
# CMakeLists.txt works with GCC, Clang and MSVC.  #include is not translated into imports by MSBuild here.

include_guard(GLOBAL)

if(NOT CMAKE_GENERATOR MATCHES "^Visual Studio")
  message(FATAL_ERROR "HeaderUnits: with MSVC use a Visual Studio generator (MSBuild builds header units itself); "
    "CMake's '${CMAKE_GENERATOR}' generator does not support header units with MSVC.")
endif()

function(add_header_units set)
  cmake_parse_arguments(PARSE_ARGV 1 A "" "CXX_STANDARD;CXX_EXTENSIONS;POSITION_INDEPENDENT_CODE"
    "HEADERS;LINK_LIBRARIES;COMPILE_DEFINITIONS;COMPILE_OPTIONS;INCLUDE_DIRECTORIES")
  if(A_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "add_header_units(${set}): unexpected arguments: ${A_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT A_HEADERS)
    message(FATAL_ERROR "add_header_units(${set}): HEADERS is required.")
  endif()
  set_property(GLOBAL APPEND PROPERTY _HU_MSVC_SETS ${set})
endfunction()

function(target_import_header_units consumer set)
  cmake_parse_arguments(PARSE_ARGV 2 A "" "" "SOURCES")
  if(A_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "target_import_header_units(${consumer} ${set}): unexpected arguments: ${A_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT TARGET ${consumer})
    message(FATAL_ERROR "target_import_header_units: '${consumer}' is not a target.")
  endif()
  get_property(sets GLOBAL PROPERTY _HU_MSVC_SETS)
  if(NOT set IN_LIST sets)
    message(FATAL_ERROR "target_import_header_units(${consumer} ${set}): no header-unit set '${set}' (add_header_units).")
  endif()
  set_property(TARGET ${consumer} PROPERTY CXX_SCAN_FOR_MODULES ON)
endfunction()

function(target_auto_header_units tgt)
  if(NOT TARGET ${tgt})
    message(FATAL_ERROR "target_auto_header_units: '${tgt}' is not a target.")
  endif()
  set_property(TARGET ${tgt} PROPERTY CXX_SCAN_FOR_MODULES ON)
endfunction()
