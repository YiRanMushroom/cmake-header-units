# importers of mx in ANOTHER directory
add_executable(a02_plain main.cpp)
target_link_libraries(a02_plain PRIVATE mx)
add_executable(a02_synth main_synth.cpp)
target_link_libraries(a02_synth PRIVATE mx)
target_compile_options(a02_synth PRIVATE -O2)        # Kitware #28166 -> CMake synthesizes mx@synth_N here
add_executable(a02_hu main_hu.cpp)
target_link_libraries(a02_hu PRIVATE mx)
target_import_header_units(a02_hu hu_tiny)
