add_executable(ta main.cpp)
target_include_directories(ta PRIVATE include)
target_auto_header_units(ta)
