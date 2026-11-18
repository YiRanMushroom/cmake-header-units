cmake_minimum_required(VERSION 3.28...4.5)
project(t18_spelling LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# An explicit set; its consumer, in a directory processed later, spells the same include directory differently
# ("app/../inc"): GCC names the header by the consumer's spelling.
# Both list a directory that does not exist first (e.g. one generated at build time).
add_header_units(t18_set HEADERS sp.h INCLUDE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/missing" "${CMAKE_CURRENT_SOURCE_DIR}/inc")
add_subdirectory(app)

enable_testing()
add_test(NAME t18 COMMAND t18)
