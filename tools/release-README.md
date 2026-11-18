# HeaderUnits.cmake (release branch)

C++20 header units with CMake for GCC and Clang, and a pass-through for MSVC with a Visual Studio generator. This
branch holds only the module (`cmake/`) and the license; documentation, tests and history are on the main branch:
https://github.com/YiRanMushroom/cmake-header-units

```cmake
include(FetchContent)
FetchContent_Declare(cmake_header_units
  GIT_REPOSITORY https://github.com/YiRanMushroom/cmake-header-units.git
  GIT_TAG        release               # a branch or tag; for a commit hash, drop GIT_SHALLOW
  GIT_SHALLOW    TRUE)
FetchContent_MakeAvailable(cmake_header_units)
list(APPEND CMAKE_MODULE_PATH "${cmake_header_units_SOURCE_DIR}/cmake")
include(HeaderUnits)   # in the top-level CMakeLists.txt, after project(), before any add_subdirectory()
```

Each commit of this branch names the main commit its files come from.

License: MIT (`LICENSE`).
