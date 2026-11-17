# Third-party libraries used by the tests, as IMPORTED targets with the same names on every platform.
#   Linux (container): Debian packages via find_package (fmt::fmt is a compiled shared library there).
#   Windows: header-only, from <repo>/ext-src/fmt (10.1.1) and <repo>/ext-src/nlohmann_json (3.11.3); see README.
if(WIN32)
  set(HU_EXT_SRC "${CMAKE_CURRENT_LIST_DIR}/../../ext-src" CACHE PATH "fmt / nlohmann_json sources (Windows)")
  get_filename_component(HU_EXT_SRC "${HU_EXT_SRC}" ABSOLUTE)
  if(NOT TARGET fmt::fmt)
    add_library(fmt::fmt INTERFACE IMPORTED)
    set_target_properties(fmt::fmt PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${HU_EXT_SRC}/fmt/include"
      # FMT_CONSTEVAL=: fmt 10.1.1's format-inl.h does not compile with Clang 22 + MSVC STL in header-only mode
      # ("call to consteval function fmt::basic_format_string... is not a constant expression"), header units
      # or not; this turns the compile-time format-string check into a runtime one.
      INTERFACE_COMPILE_DEFINITIONS "FMT_HEADER_ONLY=1;FMT_CONSTEVAL=")
  endif()
  if(NOT TARGET nlohmann_json::nlohmann_json)
    add_library(nlohmann_json::nlohmann_json INTERFACE IMPORTED)
    set_target_properties(nlohmann_json::nlohmann_json PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${HU_EXT_SRC}/nlohmann_json/single_include")
  endif()
  set(HU_HAVE_BOOST OFF)
else()
  find_package(fmt REQUIRED)
  find_package(nlohmann_json REQUIRED)
  find_package(Boost REQUIRED CONFIG COMPONENTS headers)
  set(HU_HAVE_BOOST ON)
endif()
