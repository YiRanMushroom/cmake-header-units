cmake_minimum_required(VERSION 3.28...4.5)
project(t17_lookup LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# The header lookup follows the compiler's include search list:
# - first/ and second/ (-I, in that order) both hold shadow.h: first/ wins; sys/ has one too, but -isystem
#   directories (an IMPORTED target's) come after every -I one;
# - onlysys.h is found through the IMPORTED target only;
# - first/ is spelled with "..": the module and GCC must name the header the same way;
# - (not on Windows) linked.h sits in a directory reached through a symbolic link.
# - flagsys.h: found through -isystem in CMAKE_CXX_FLAGS; relonly.h: through CMAKE_CXX_FLAGS_RELEASE only, and imported
#   under #ifdef NDEBUG (in Debug the import is inactive and the header not found: it must be skipped);
# - cur.h: found through CMAKE_INCLUDE_CURRENT_DIR (not a target property);
# - the C++ library's directory given again with -I: the compiler keeps it as a system directory.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -isystem ${CMAKE_CURRENT_SOURCE_DIR}/flagsys")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -isystem ${CMAKE_CURRENT_SOURCE_DIR}/relsys")
set(CMAKE_INCLUDE_CURRENT_DIR ON)

add_library(t17_sys INTERFACE IMPORTED)
set_target_properties(t17_sys PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/sys")

add_executable(t17 main.cpp)
target_include_directories(t17 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/sys/../first" "${CMAKE_CURRENT_SOURCE_DIR}/second")
target_link_libraries(t17 PRIVATE t17_sys)
if(CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
  list(GET CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES 0 t17_cxxdir)
  target_include_directories(t17 PRIVATE "${t17_cxxdir}")
endif()
if(NOT CMAKE_HOST_WIN32)
  file(CREATE_LINK "${CMAKE_CURRENT_SOURCE_DIR}/linked_dir" "${CMAKE_CURRENT_BINARY_DIR}/linked" SYMBOLIC)
  target_include_directories(t17 PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/linked")
  target_compile_definitions(t17 PRIVATE T17_LINKED=1)
endif()
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 16)
  # an option the compiler refuses without the right -std: the lookup runs with the set's language level
  set_target_properties(t17 PROPERTIES CXX_STANDARD 26)
  target_compile_options(t17 PRIVATE -freflection)
endif()
target_auto_header_units(t17)

enable_testing()
add_test(NAME t17 COMMAND t17)
