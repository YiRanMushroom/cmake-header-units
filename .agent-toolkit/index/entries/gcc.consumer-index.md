+++
title = "GCC hu-index.txt: one line per importing (target, source); a non-importing target of the source gets no map"
kind = "code"
keys = [ "gcc", "hu-index", "hu-mapper", "non-importing target", "object dir", "shared source", "synth", "t26" ]
updated = "2026-11-19 18:14:31"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/hu-mapper.cpp"
snippet = "std::string lookup(const std::string& index, const std::string& source, const std::string& modmap) {"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_objdir out t)"
+++
Line: "<objdir>|<target>|<source>|<map>" (_hu_gcc_objdir: <binary dir>/CMakeFiles/<t>.dir, relative to the top build dir), written for all the source's importing targets at once (the macro runs once per (directory, source)). hu-mapper -c (lookup()), gcc-mapper.sh and gcc-mapper.cmd match the source and require that the compile's module map (<MODULE_MAP_FILE> / $out.modmap: object path + ".modmap") lies in that object dir. So a target that compiles the source without importing header units gets no map: its #include stays textual. Before (index keyed by source only) such a target in another directory got the map and GCC imported a CMI nothing ordered before its compile (clean "ninja t26_plain": "import of '.../t26.h' failed, falling back to include", the CMI in its depfile; Linux GCC when the include-dir spelling matches, MinGW always). A compile of a target CMake synthesizes (Kitware #28166, ".../CMakeFiles/<t>@synth_<n>.dir") gets <t>'s line (t03 -synth). Not Ninja's $OBJECT_DIR: backslashes on Windows, which GCC's mapper-argument splitter takes as escapes (tried: every MinGW consumer lost its map). Index format change = hu-mapper version 3 (Common.cmake rebuilds an older program). Left: a non-importing target in the SAME directory as an importer shares the source properties (scan map, OBJECT_DEPENDS); its compile is textual too. Test: t26_shared_targets.