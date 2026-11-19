# the same source, without header units, and with the same spelling of the include directory as t26_imp (GCC names a
# header unit by it: the map of src/plain.cpp would apply to this compile)
add_executable(t26_plain ../src/plain.cpp)
target_include_directories(t26_plain PRIVATE "${PROJECT_SOURCE_DIR}/inc")
