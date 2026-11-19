cmake_minimum_required(VERSION 3.28...4.5)
project(t15_scan_sources LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

# Only the listed sources are scanned and receive header units, in two calls: a.cpp -> t15_hu (<cfg.h>, <vector>);
# b.cpp -> t15_hu_2 (<string>), reusing t15_hu's <vector>.  c.cpp is not listed: it defines CFG_MODE before a textual
# #include <cfg.h>, which must stay textual (as a header unit the definition would have no effect).  m15.cppm, a module
# interface unit listed in a third call, imports <cfg.h> too: with MSVC the target's sources then also see that header
# unit (for importers of m15), and c.cpp's #include must stay textual all the same.
add_executable(t15 a.cpp b.cpp c.cpp)
target_sources(t15 PRIVATE FILE_SET CXX_MODULES FILES m15.cppm)
target_include_directories(t15 PRIVATE inc)
target_header_units_scan_sources(t15 a.cpp)
target_header_units_scan_sources(t15 b.cpp)
target_header_units_scan_sources(t15 m15.cppm)
if(T15_BAD)
  target_header_units_scan_sources(t15 not_a_source.cpp)
endif()

enable_testing()
add_test(NAME t15 COMMAND t15)
