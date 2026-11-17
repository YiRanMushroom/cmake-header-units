add_executable(a03_d1 ../common/shared.cpp main1.cpp)
target_link_libraries(a03_d1 PRIVATE tiny3::tiny3)
target_import_header_units(a03_d1 hu_t3)
