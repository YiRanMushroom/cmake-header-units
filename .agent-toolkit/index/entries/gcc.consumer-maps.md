+++
title = "GCC consumer maps are computed once per (search list, sets): per source it cost 42 s for 1000 sources"
kind = "code"
keys = [ "configure time", "consumer map", "gcc", "performance" ]
updated = "2026-11-19 03:54:56"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "    string(MD5 _hu_gck \"${_hu_cs_${tk}_KEY}|${tsets}\")"
+++
Profiled (--profiling-format=google-trace) on 40 targets, 1000 sources, 70 headers, MinGW GCC 16.1, CMake 4.5.0: _hu_gcc_keys (file-system queries) ran 70143 times and src-index.txt was rewritten per source: 42.5 s configure. Cached per search list + sets, index written once (_hu_GCC_consumers_done): 7.6 s, maps identical. Left: per-source map writes, auto scans, CMake's compiler detection (~1.5 s).