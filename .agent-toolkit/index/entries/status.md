+++
title = "Status: where the work stands"
+++
Written 2026-11-19 at main (see git log; this note is committed with the work). Last version tag: v0.1.0. The `release` branch holds the module of f2767f7 (d1e83cc); not updated since.

What the owner wants (clarified 2026-11-19): "lean and fast" means: decide which features to support, write them mostly in one go, then adapt them bit by bit -- not dropping what should be supported. The owner keeps every feature: HU_ALLOW_HEADER_IMPORTS, the HU_GCC_WRAPPERS fallback, hu-mapper's import scan, Ninja Multi-Config, target_header_units_scan_sources. Known gaps are work to do (support them), not things to leave.

Done since f2767f7:
- Dead and duplicate code removed with no behaviour change (8e0ce15): build.ninja, maps, response files, hu-index.txt and manifests of t02, t04, t08 byte-identical before and after on mingw, win, clangcl, msvc.
- MSVC with Ninja: a module interface source of two targets of one directory gives both targets' importers its header units (ae93aa5, t27; failed before with C7612).
- Driver: t01's locked-source check works in a double-byte console code page (936).
- README: Results is one table of the full matrix.

Verified (full matrix, 2026-11-19, the table in README Results): Linux gcc/clang/libcxx 27/27 with CMake 4.5.0, 26 + t22 SKIP with 4.4.5; Windows win 27/27, clangcl 27/27, mingw 26 + XFAIL t02, msvc 24 + XFAIL t02/t08/t11; MSBuild (run-msvc.bat) 11 + XFAIL t02/t08/t11. (t01 on mingw/win/clangcl re-run after the driver fix.)

In progress / open, in order:
1. Done: (A) the compatibility check compares the directories' flags without warning, diagnostic and debug-information options (t04 variant T04_WARN, passes on mingw, win, clangcl, msvc, Linux gcc/clang/libcxx). (C) MSVC in a non-ASCII directory: the self-check reads cl's /showIncludes with ENCODING ANSI, and MSVC response files are written with a UTF-8 byte order mark (cl then reads them as UTF-8; without one as ANSI); t01's non-ASCII project runs for msvc as "*-é" (configure, build, run). Left, outside the module: Ninja records cl's /showIncludes in the ANSI code page while build.ninja is UTF-8, so in a non-ASCII directory every build recompiles -- a plain CMake project (cl, C++20, no HeaderUnits) does the same; a character outside the ANSI code page cannot work with cl.
3. Done: (B) Ninja Multi-Config: the header lookup uses each configuration's CMAKE_CXX_FLAGS_<CONFIG>; a header that the configurations find as different files stops the configure naming the header, the configurations and the files (t23: relinc/ agrees, T23_SHADOW's <vector> stops; Debug and RelWithDebInfo share a run, filtered like the options). Verified (CMake 4.5.0 on Windows, the image's 4.4.5 on Linux): mingw t04, t23, t17, t25; win t04, t23, t17; clangcl and msvc t04, t23; Linux gcc, clang, libcxx t23 (all PASS).
4. (E) Auto.cmake (_hu_auto_inputs) and Common.cmake (_hu_target_cxx_sources) collect a target's sources by different rules (default module file set, generator expressions, build-directory sources, extensions): one function. A subagent worked on it in a worktree.
5. HU_GCC_WRAPPERS with a build directory outside the ANSI code page fails (g++-mapper-server and cmd scripts read narrow paths): check whether it can be supported.
6. Ask the owner about a v0.1.1 tag and updating `release` once 1-4 are in.

Learned while testing:
- Every wait has a timeout of at most 3 minutes, longer work is checked again every 3 minutes (instructions.project).
- This machine (32 threads, 64 GB): all four Windows suites plus two Linux containers at once work (about 5 minutes). On a 16 GB machine four suites at once froze it: there one toolchain at a time, e.g. JOBS=2 NINJA_JOBS=5, and Linux and Windows runs not at the same time.
- Docker Desktop may not be running ("open //./pipe/dockerDesktopLinuxEngine"): start "C:\Program Files\Docker\Docker\Docker Desktop.exe" and wait for `docker info`.
- The driver reads child output in the console code page; with a double-byte one (936 here) non-ASCII paths in messages are garbled and can swallow a following "/": match messages loosely around them.
- `wsl -d <distro> -- bash script.sh "t01;t02"`: the ; ends the command that wsl.exe hands to the shell (exit 127); pass commas and turn them into ; inside the script.
- t26 on Linux GCC only fails without the fix when the two targets spell the include directory the same way; MinGW always.
