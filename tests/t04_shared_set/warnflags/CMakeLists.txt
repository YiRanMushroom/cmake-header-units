# A consumer in another directory whose flags add only warning and debug-information options: compatible with the set.
if(MSVC)
  string(APPEND CMAKE_CXX_FLAGS " /W4")
else()
  string(APPEND CMAKE_CXX_FLAGS " -Wall -Wextra")
  string(APPEND CMAKE_CXX_FLAGS_DEBUG " -g3")
endif()
add_executable(t04_warn ../a.cpp)
target_import_header_units(t04_warn hu_std)
