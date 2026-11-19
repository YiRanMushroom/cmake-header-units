cmake_minimum_required(VERSION 3.28...4.5)
project(t12_build_tree LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")
include(HeaderUnits)
include(FetchContent)

# A FetchContent dependency, extracted into <build>/_deps/tinydep-src (inside the build tree). The "download"
# is a local tarball so the test needs no network.
execute_process(COMMAND "${CMAKE_COMMAND}" -E tar czf "${CMAKE_BINARY_DIR}/tinydep.tar.gz" tinydep
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/vendor" COMMAND_ERROR_IS_FATAL ANY)
FetchContent_Declare(tinydep URL "${CMAKE_BINARY_DIR}/tinydep.tar.gz" DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(tinydep)

# A header generated at configure time into the build tree.
set(T12_VALUE 3)
configure_file(gen_config.h.in "${CMAKE_BINARY_DIR}/gen/gen_config.h")
# A consumer source generated at configure time into the build tree.
configure_file(gen_src.cpp.in "${CMAKE_BINARY_DIR}/gen/gen_src.cpp" COPYONLY)

add_executable(t12 main.cpp other.cpp "${CMAKE_BINARY_DIR}/gen/gen_src.cpp")
target_include_directories(t12 PRIVATE "${CMAKE_BINARY_DIR}/gen")
target_link_libraries(t12 PRIVATE tinydep)
target_auto_header_units(t12)

enable_testing()
add_test(NAME t12 COMMAND t12)
