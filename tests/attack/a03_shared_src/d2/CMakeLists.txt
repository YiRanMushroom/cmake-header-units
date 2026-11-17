add_executable(a03_d2 ../common/shared.cpp main2.cpp)
target_link_libraries(a03_d2 PRIVATE tiny3::tiny3)
target_import_header_units(a03_d2 hu_t3)
