+++
title = "A header in two sets of one directory: one set of source properties, so options must not depend on the set"
kind = "design"
keys = [ "clang-cl", "ifcoutput", "msvc", "object_name", "source properties", "t24", "target_property:name", "two sets" ]
updated = "2026-11-19 17:17:28"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "set(rcmi \"${od}/$<TARGET_PROPERTY:NAME>.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}\")"

[[links]]
path = "cmake/HeaderUnits/Clang.cmake"
snippet = "get_property(prev_oname GLOBAL PROPERTY _HU_CLANG_ONAME_${dk})"

[[links]]
path = "tests/run_suite.cmake"
snippet = "function(test_t24_two_sets bdir)"
+++
Source properties (OBJECT_NAME, COMPILE_OPTIONS) are per directory, so a header in two sets of one directory gets the LAST set's. Clang and MSVC: the second set reuses the first one's OBJECT_NAME (keyed by directory + real path; the header may be spelled differently, <val.h> vs <t24/val.h>), and an output path in the options names the set's directory as $<TARGET_PROPERTY:NAME> (clang-cl /clang:-o, MSVC /ifcOutput). Before the MSVC fix (2026-11-19): every set's compile wrote the last set's IFC (C3474 could not open output file), and another spelling moved the first set's object (ninja: missing and no known rule). GCC rejects the second set at configure time (one header unit per header per build tree). A TU that gets both sets is rejected (would get two header units). t24 checks it.