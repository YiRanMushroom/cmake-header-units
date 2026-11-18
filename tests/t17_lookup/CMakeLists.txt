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
add_library(t17_sys INTERFACE IMPORTED)
set_target_properties(t17_sys PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/sys")

add_executable(t17 main.cpp)
target_include_directories(t17 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/sys/../first" "${CMAKE_CURRENT_SOURCE_DIR}/second")
target_link_libraries(t17 PRIVATE t17_sys)
if(NOT CMAKE_HOST_WIN32)
  file(CREATE_LINK "${CMAKE_CURRENT_SOURCE_DIR}/linked_dir" "${CMAKE_CURRENT_BINARY_DIR}/linked" SYMBOLIC)
  target_include_directories(t17 PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/linked")
  target_compile_definitions(t17 PRIVATE T17_LINKED=1)
endif()
target_auto_header_units(t17)

enable_testing()
add_test(NAME t17 COMMAND t17)
