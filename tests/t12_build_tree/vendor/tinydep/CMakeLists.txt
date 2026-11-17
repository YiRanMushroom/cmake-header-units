cmake_minimum_required(VERSION 3.28...4.5)
add_library(tinydep INTERFACE)
target_include_directories(tinydep INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
