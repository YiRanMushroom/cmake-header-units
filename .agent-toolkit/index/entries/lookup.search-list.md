+++
title = "Header lookup without try_compile: the compiler's -E -v search list, first match; GCC mapper keys for every spelling"
keys = [ "configure time", "gcc", "lookup", "search list", "spelling", "try_compile" ]
updated = "2026-11-18 22:01:10"
checked = "2026-11-18"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_search_dirs out)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_keys out p name)"
+++
A set's headers (and an auto request's names) are resolved in the include search list the compiler prints for the set's flags ("<compiler> <flags> -x c++ -E -v": -I dirs, then -isystem ones such as imported targets', then its own), first match; one compiler run per distinct flag set, about 0.1 s. It replaced a try_compile probe per set, ~3.3 s each on Windows, which made configure grow with the number of targets (the user decided: no try_compile at all; test the toolchains instead).
GCC keys header units by its own spelling of the path, which differs by platform: on Linux an -I directory as given is kept ("x/sys/../first/shadow.h"), system directories come normalized even though -v prints them with "../.."; on Windows (MinGW) everything is normalized. So the mapper files list the normalized path, the real path, and each raw -v spelling of the directory plus the name (_HU_RAWDIRS_*), all for the same CMI; GCC accepts a CMI built under another spelling. Not covered: a consumer whose own -I spelling differs from the set's (explicit add_header_units). t17_lookup tests the order, ".." and a symlink.