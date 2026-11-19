add_executable(tb ../src/main.cpp)
target_include_directories(tb PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../inc")
target_import_header_units(tb t25_set)

# the same source again in this directory (its source properties are this directory's), with yet another spelling
add_executable(tc ../src/main.cpp)
target_include_directories(tc PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../b/../inc")
target_import_header_units(tc t25_set)
