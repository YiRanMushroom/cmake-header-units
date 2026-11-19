+++
title = "Header lookup: one -E -v per option set, each target's list assembled in CMake, self-check; GCC keys per consumer"
keys = [ "configure time", "gcc", "lookup", "search list", "spelling", "try_compile" ]
updated = "2026-11-19 17:27:47"
checked = "2026-11-18"

[[items]]
name = "context"
value = "Target properties: CMAKE_INCLUDE_CURRENT_DIR, INCLUDE_DIRECTORIES (incl. include_directories()), LINK_LIBRARIES usage requirements, COMPILE_OPTIONS (incl. add_compile_options()), CXX_STANDARD/EXTENSIONS. add_header_units creates the set target first."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_target_search p tgt)"

[[items]]
name = "base-run"
value = "Key: ARG1, CMAKE_CXX_FLAGS(+_<CFG>), sysroot/target/toolchain, the -std option (GCC refuses -freflection without it), options except -W/-D/-U/-O/-g. No include dirs: marker dirs -I mI -isystem mS stand for them (clang-cl: -I mI /external:I mB -imsvc mS, see clang.clang-cl). A printed list is used whatever the exit code."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_search_base p)"

[[items]]
name = "assembly"
value = "The target's -I/-isystem dirs go at the markers (CMake's rule: $DEFINES $INCLUDES $FLAGS); implicit dirs, missing dirs, repeats (first stays, by real path) and -I copies of system dirs are dropped."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_search_list p)"

[[items]]
name = "gcc-keys"
value = "GCC names a header unit by its spelling (Linux keeps -I dirs as given, MinGW normalizes). A source's map has the keys of every target compiling it (gcc.consumer-maps, t25): first dir holding <name>, if the same file: its spelling+\"/name\", normalized; always p, real path (t18)."
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_keys out p name)"

[[items]]
name = "self-check"
value = "Finalize, 1 run with the first lookup's options: -E -H of a probe (header via sub/../inc shadowing -isystem, -isystem-only one, <cstddef>); a file other than predicted (GCC: a name not among the keys) is FATAL, a header not opened only warns. Probe headers need distinct contents (GCC #pragma once)."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_self_check)"

[[items]]
name = "same-file"
value = "A consumer finding, for a header of its sets, another file without a header unit gets a WARNING (t20); a reused set bringing another <config.h> is fine (t13)."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_check_same_files consumer)"

[[items]]
name = "auto-order"
value = "Auto passes the set the target's dirs/libs first, then the call's extras (the order _hu_target_search uses); after add_header_units a guard FATALs if the set resolved a name to another file than the target. Missing dirs are skipped before the parallel lists (no empty placeholders)."
path = "cmake/HeaderUnits/Auto.cmake"
snippet = "# The set looks its headers up from its own target: it must find the files this target finds."
+++
<name> is resolved in the search list of a target as CMake compiles it, first match; one function reads the context for every caller (set lookup, auto requests, finalize checks). The compiler runs once per distinct option set, never per target (user requirement: no try_compile, no per-target compiles, configure cost not growing with the project; t19_scale asserts 5 and 40 targets give the same count, printed as STATUS "header lookup: <n> compiler run(s)"). An empty-file try_compile to capture flags was tried and rejected (works, but +0.6 s per config and parsing Ninja's log). Identity is the real path everywhere (_HU_REAL_SET_<md5>). Details per item.