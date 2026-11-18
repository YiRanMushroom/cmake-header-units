add_executable(t18 main.cpp)
target_include_directories(t18 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../inc")
target_import_header_units(t18 t18_set)
