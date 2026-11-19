add_executable(ta ../src/main.cpp)
target_include_directories(ta PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../inc")
target_import_header_units(ta t25_set)
