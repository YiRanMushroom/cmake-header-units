+++
title = "GCC consumer maps: one per source with the spellings of all its targets, computed once per (search lists, sets)"
kind = "code"
keys = [ "configure time", "consumer map", "gcc", "hu-index", "performance", "shared source", "spelling" ]
updated = "2026-11-19 18:14:40"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "string(MD5 _hu_gck \"${_hu_gkeys}|${tsets}\")"
+++
Profiled (--profiling-format=google-trace) on 40 targets, 1000 sources, 70 headers, MinGW GCC 16.1, CMake 4.5.0: _hu_gcc_keys (file-system queries) ran 70143 times and src-index.txt was rewritten per source: 42.5 s configure. Cached per search list + sets, index written once (_hu_GCC_consumers_done): 7.6 s, maps identical. Left: per-source map writes, auto scans, CMake's compiler detection (~1.5 s).

One map per source, not per (target, source): the scan gets it through a source property (per directory, so a second target of the same directory gets the first one's options) and the compile through hu-index.txt by source path and object dir (gcc.consumer-index). GCC names a header by the spelling of the include directory, which is each target's own, so the map holds the keys of every target that compiles the source (_hu_gst_<md5(src)>, built once from Core.cmake's TUs): sound because a key is a spelling of the header's own path, a header has one header unit per build tree and a source has one set list. With a single distinct search list the map is the same as before (same cache key and content). Before this, the first target won: Linux GCC failed for a second target in another directory ("unknown compiled module interface", compile) or in the same directory ("failed to read compiled module", scan); MinGW GCC normalizes the path and was not affected. Test: t25_shared_source.