add_executable(t26_imp ../src/plain.cpp)
target_include_directories(t26_imp PRIVATE "${PROJECT_SOURCE_DIR}/inc")
target_import_header_units(t26_imp t26_set)
