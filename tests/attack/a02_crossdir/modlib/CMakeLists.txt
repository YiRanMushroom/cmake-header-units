add_library(mx STATIC)
target_sources(mx PUBLIC FILE_SET CXX_MODULES FILES m.cppm)
target_link_libraries(mx PUBLIC tiny2::tiny)
target_import_header_units(mx hu_tiny)
