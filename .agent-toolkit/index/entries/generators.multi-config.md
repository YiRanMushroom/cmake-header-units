+++
title = "Ninja Multi-Config (GCC, Clang): per-configuration BMIs and files, no OBJECT_DEPENDS; MSVC rejected"
keys = [ "$<config>", "_hu_cfg", "_hu_write", "file(generate)", "multi-config", "ninja multi-config", "object_depends" ]
updated = "2026-11-19 06:07:01"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits.cmake"
snippet = "set_property(GLOBAL PROPERTY _HU_CFG \"$<CONFIG>/\")"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_write path content)"
+++
_HU_CFG is "$<CONFIG>/" in a multi-config tree (else ""): it goes into BMI paths (CMakeFiles/<set>.dir/<cfg>/hu/...) and the paths of files naming BMIs (Clang rsp, GCC hmap/gcc-m maps, hu-index.txt), written by _hu_write (file(GENERATE) there, file(CONFIGURE) single-config). GCC's CMAKE_CXX_MODULE_MAP_FLAG names <hudir>/$CONFIG/hu-index.txt: Ninja's CONFIG variable is set on every multi-config compile edge (CMAKE-INTERNAL). OBJECT_DEPENDS takes no genex (CMake escapes $ to $$), so consumers get none: <set>_ready (a utility target) puts set$:<cfg> into cmake_object_order_depends_target_<consumer>_<CFG>, ordering scan and compile; GCC and Clang depfiles name the BMIs (probed), so rebuilds work. MSVC: /showIncludes lists no IFCs -> rejected; GCC without hu-mapper and HU_ALLOW_HEADER_IMPORTS (intra-set order needs OBJECT_DEPENDS) rejected. t23 verifies (Debug/Release, NDEBUG-dependent header, edit and deleted-BMI rebuilds); configure with default CMAKE_CONFIGURATION_TYPES (a ';' list in the driver's run() splits).