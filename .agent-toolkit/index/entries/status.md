+++
title = "Status: where the work stands"
+++
Written 2026-11-19 at main (see git log; this note is committed with the work). Last version tag: v0.1.1 (on release 2143c70). The `release` branch is at 2143c70 (the module of main 2386663, pushed 2026-11-20 at the owner's word), tagged v0.1.1.

What the owner wants (clarified 2026-11-19): "lean and fast" means: decide which features to support, write them mostly in one go, then adapt them bit by bit -- not dropping what should be supported. The owner keeps every feature: HU_ALLOW_HEADER_IMPORTS, the HU_GCC_WRAPPERS fallback, hu-mapper's import scan, Ninja Multi-Config, target_header_units_scan_sources. Known gaps are work to do, not things to leave. Every wait has a timeout of at most 3 minutes (instructions.project).

Done since f2767f7 (all on main, pushed):
- Dead and duplicate code removed, no behaviour change (build files of t02, t04, t08 byte-identical before/after on mingw, win, clangcl, msvc).
- MSVC with Ninja: a module interface source of two targets of one directory gives both targets' importers its header units (t27).
- Compatibility check: the directories' CMAKE_CXX_FLAGS[_<CONFIG>] are compared without warning, diagnostic and debug-information options (t04 T04_WARN).
- MSVC in a non-ASCII directory: self-check reads /showIncludes with ENCODING ANSI; response files carry a UTF-8 BOM (t01 runs "*-é" for msvc). Outside the module: Ninja records cl's /showIncludes in ANSI while build.ninja is UTF-8, so such builds always recompile (a plain CMake project does the same); characters outside the ANSI code page cannot work with cl.
- GCC without hu-mapper: a non-ASCII build directory or header path is rejected at configure time (GCC quotes it; its own mapper-file reader cannot read quotes).
- Ninja Multi-Config: the header lookup uses each configuration's flags; a header found as different files (or only in some configurations) stops the configure (t23). Strict on purpose: a set's header unit is built in every configuration.
- One rule for a target's C++ sources for the scan and the header units (_hu_target_cxx_sources; note sources.cxx-sources; t28): generator-expression sources skipped, LANGUAGE / HEADER_FILE_ONLY / CMAKE_CXX_SOURCE_FILE_EXTENSIONS decide, build-directory sources by relative path; names without an extension (CMP0115 OLD) are skipped as before.
- Driver: t01's locked-source check in a double-byte console code page; README Results is one table.

Verified: the full matrix at 69a26f9 (README Results): Linux gcc/clang/libcxx 28/28 with CMake 4.5.0, 27 + t22 SKIP with 4.4.5; Windows win 28/28, clangcl 28/28, mingw 27 + XFAIL t02, msvc 25 + XFAIL t02/t08/t11; MSBuild (run-msvc.bat, earlier the same day) 11 + XFAIL t02/t08/t11. After it (the CMP0115 skip, a t28 case): t03, t08, t15, t28 on mingw, win, clangcl, msvc and t08, t15, t28 on Linux gcc/clang/libcxx (CMake 4.4.5): PASS (msvc t08 XFAIL).

Open:
1. Not covered by a test: the consumer warning naming a configuration (Multi-Config), GCC map keys for one file reached through differently spelled directories in different configurations, a GENERATED source with a same-named file in the source directory.

Out of scope (owner, 2026-11-20): sources a linked library adds through INTERFACE_SOURCES. Neither command sees them; a library that imports header units in such a source is responsible for making it compile.

Learned while testing:
- This machine (32 threads, 64 GB): all four Windows suites plus two Linux containers at once work, 5-7 minutes; slower when also subagents run tests. On a 16 GB machine four suites at once froze it: there one toolchain at a time, e.g. JOBS=2 NINJA_JOBS=5, and Linux and Windows runs not at the same time.
- Docker Desktop may not be running ("open //./pipe/dockerDesktopLinuxEngine"): start "C:\Program Files\Docker\Docker\Docker Desktop.exe" and wait for `docker info`.
- The driver reads child output in the console code page; with a double-byte one (936 here) non-ASCII paths in messages are garbled and can swallow a following "/": match messages loosely around them. A .bat with a non-ASCII path in it is read in the OEM code page: run such commands from bash.
- `wsl -d <distro> -- bash script.sh "t01;t02"`: the ; ends the command that wsl.exe hands to the shell (exit 127); pass commas and turn them into ; inside the script.
- t26 on Linux GCC only fails without the fix when the two targets spell the include directory the same way; MinGW always.
