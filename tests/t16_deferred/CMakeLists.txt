cmake_minimum_required(VERSION 3.28...4.5)
project(t16_deferred LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)

add_subdirectory(app)
if(T16_LATE)
  # a change from another directory after app/ was processed: not seen by the header units, reported as a warning
  target_compile_definitions(t16 PRIVATE T16_LATE_DEF=1)
endif()

enable_testing()
add_test(NAME t16 COMMAND t16)
add_test(NAME t16b COMMAND t16b)
