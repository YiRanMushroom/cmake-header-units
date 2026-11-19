+++
title = "Configure-time import scan and header lookup in hu-mapper (all toolchains), CMake functions as fallback"
keys = [ "configure time", "hu-mapper", "hu_native_scan", "native scan", "performance", "scan cache", "target_auto_header_units" ]
updated = "2026-11-19 06:01:48"
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
hu-mapper.cpp "scan" computes what Common.cmake's _hu_scan_imports / _hu_import_name / _hu_find_header compute (the fallback, -DHU_NATIVE_SCAN=OFF): keep them in step. It emulates file(STRINGS) splitting (a byte outside printable ASCII/tab ends a line piece, except non-ASCII after a UTF-8 BOM; \r dropped). Paths in request/result/cache are UTF-8 (Windows: _wfopen, fs::u8path); request/result are passed relative to WORKING_DIRECTORY because argv is not UTF-8 on Windows.
Auto.cmake: _hu_auto_prescan batches every not-yet-run request of a directory into one run; _hu_auto_run recomputes its inputs (sources, search list) and falls back to CMake's scan if an earlier request changed them. Core: _hu_scan_markers reads all consumers' textual-includes markers in one run. Helper is built in _hu_build_helper (with CMAKE_CXX_FLAGS, retried without them); scan-cache.txt is deleted when the helper is rebuilt.
Verified: same build.ninja/manifest native vs CMake (driver t08 compares after a reconfigure: CMake writes TARGET_PDB differently on a fresh MinGW configure). 1000-source tree: reconfigure ~2 s native vs 3-3.5 s CMake (MinGW, clang++, MSVC). Ninja passes compiled sources by ABSOLUTE path even inside the build tree (t12 gen_src.cpp), so hu-index keys are absolute.