+++
title = "Ninja Multi-Config (GCC, Clang): per-configuration BMIs and files, no OBJECT_DEPENDS; MSVC rejected"
keys = [ "$<config>", "_hu_cfg", "_hu_check_compat", "_hu_configs", "_hu_write", "cmake_configuration_types", "compatibility check", "file(generate)", "multi-config", "ninja multi-config", "object_depends" ]
updated = "2026-11-19 17:16:46"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits.cmake"
snippet = "set_property(GLOBAL PROPERTY _HU_CFG \"$<CONFIG>/\")"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_write path content)"

[[items]]
name = "compat-check"
value = "_hu_check_compat compares CMAKE_CXX_FLAGS_<CFG> (upper case) and the ABI definitions (_ITERATOR_DEBUG_LEVEL default per configuration, _hu_abi_defs_cfg) for every configuration, the line naming it; t04 re-runs T04_BAD=cfgflags and abi with Ninja Multi-Config (not msvc)."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_configs out)"
+++
_HU_CFG is "$<CONFIG>/" in a multi-config tree (else ""): it goes into BMI paths (CMakeFiles/<set>.dir/<cfg>/hu/...) and the paths of files naming BMIs (Clang rsp, GCC hmap/gcc-m maps, hu-index.txt), written by _hu_write (file(GENERATE) there, file(CONFIGURE) single-config). GCC's CMAKE_CXX_MODULE_MAP_FLAG names <hudir>/$CONFIG/hu-index.txt: Ninja's CONFIG variable is set on every multi-config compile edge (CMAKE-INTERNAL). OBJECT_DEPENDS takes no genex (CMake escapes $ to $$), so consumers get none: <set>_ready (a utility target) puts set$:<cfg> into cmake_object_order_depends_target_<consumer>_<CFG>, ordering scan and compile; GCC and Clang depfiles name the BMIs (probed), so rebuilds work. MSVC: /showIncludes lists no IFCs -> rejected; GCC without hu-mapper and HU_ALLOW_HEADER_IMPORTS (intra-set order needs OBJECT_DEPENDS) rejected. t23 verifies (Debug/Release, NDEBUG-dependent header, edit and deleted-BMI rebuilds); configure with default CMAKE_CONFIGURATION_TYPES (a ';' list in the driver's run() splits). CMAKE_BUILD_TYPE is empty here: whatever depends on the configuration loops over _hu_configs (CMAKE_CONFIGURATION_TYPES, else CMAKE_BUILD_TYPE), as _hu_check_compat does (item compat-check), and the header lookup (one search list per configuration, a header must be the same file in all: lookup.search-list item per-config).