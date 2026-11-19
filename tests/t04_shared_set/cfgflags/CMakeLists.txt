string(APPEND CMAKE_CXX_FLAGS_DEBUG " -D_GLIBCXX_DEBUG")
add_executable(t04_bad ../bad.cpp)
target_import_header_units(t04_bad hu_std)
