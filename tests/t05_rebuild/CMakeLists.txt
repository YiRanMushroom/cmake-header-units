cmake_minimum_required(VERSION 3.28...4.5)
project(t05_rebuild LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# Editable copy of the vendored library, OUTSIDE the build tree (GCC: CMake passes sources inside the build
# tree as relative paths, which would change the header-unit identity).
set(T05_VENDOR_COPY "${CMAKE_BINARY_DIR}-vendor" CACHE PATH "editable copy of vendor/include")
if(NOT EXISTS "${T05_VENDOR_COPY}/include/tiny/tiny.hpp")
  file(COPY vendor/include DESTINATION "${T05_VENDOR_COPY}")
endif()
add_library(tiny::tiny INTERFACE IMPORTED)
set_target_properties(tiny::tiny PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${T05_VENDOR_COPY}/include")

add_header_units(hu_tiny HEADERS tiny/tiny.hpp LINK_LIBRARIES tiny::tiny)

add_executable(t05 main.cpp)
target_link_libraries(t05 PRIVATE tiny::tiny)
target_import_header_units(t05 hu_tiny)
# exit code = tiny::detail::value (41, or 42 after the driver's edit); ctest is not used for t05.
