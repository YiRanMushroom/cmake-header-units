+++
title = "Configure-time import scan and header lookup in hu-mapper (all toolchains), CMake functions as fallback"
keys = [ "configure time", "hu-mapper", "hu_native_scan", "native scan", "performance", "scan cache", "target_auto_header_units" ]
updated = "2026-11-19 17:29:01"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/hu-mapper.cpp"
snippet = "int scan(const std::string& request, const std::string& result)"

[[links]]
path = "cmake/HeaderUnits/Auto.cmake"
snippet = "function(_hu_auto_prescan dir self)"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_native_scan out request)"
+++
hu-mapper.cpp "scan" computes what Common.cmake's _hu_scan_imports / _hu_import_name / _hu_find_header compute (the fallback, -DHU_NATIVE_SCAN=OFF): keep them in step. It emulates file(STRINGS) splitting (a byte outside printable ASCII/tab ends a line piece, except non-ASCII after a UTF-8 BOM; \r dropped). All paths (request/result/cache/maps/hu-index.txt) are UTF-8 (Windows: _wfopen via fs::u8path); on Windows the arguments come from CommandLineToArgvW(GetCommandLineW()) as UTF-8 (argv is ANSI). hu-mapper is linked as ../hu-mapper.exe from helper/: MinGW ld has no UTF-8 manifest. An unreadable source (open fails or ferror, e.g. a Windows lock) is not cached: "hu-mapper: cannot read <s>", exit 3, no result, so the callers fall back to CMake's scan. t01 (Windows) covers both: a generated project in t01-é中/, main.cpp held by file(LOCK) in the first configure.
Auto.cmake: _hu_auto_prescan batches every not-yet-run request of a directory into one run; _hu_auto_run recomputes its inputs (sources, search list) and falls back to CMake's scan if an earlier request changed them. Core: _hu_scan_markers reads all consumers' textual-includes markers in one run. Helper is built in _hu_build_helper (with CMAKE_CXX_FLAGS, retried without them); scan-cache.txt is deleted when the helper is rebuilt.
Verified: same build.ninja/manifest native vs CMake (driver t08 compares after a reconfigure: CMake writes TARGET_PDB differently on a fresh MinGW configure). 1000-source tree: reconfigure ~2 s native vs 3-3.5 s CMake (MinGW, clang++, MSVC). Ninja passes compiled sources by ABSOLUTE path even inside the build tree (t12 gen_src.cpp), so hu-index keys are absolute.