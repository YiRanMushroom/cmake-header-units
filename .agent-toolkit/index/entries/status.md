+++
title = "Status: where the work stands"
+++
Written 2026-11-19 at main f2767f7 (pushed), when the work moved to another machine. The `release` branch was updated from it (d1e83cc, the module of f2767f7) at the owner's word, before a full matrix; no new version tag was made (the last one is v0.1.0).

Since v0.1.0 (b0fc455), on main:
- MSVC with Ninja: one header in two sets of one directory (t24). GCC: a shared source's map holds every target's spellings (t25); hu-index.txt describes the current configure also with no consumer left (t15); a target that does not import header units gets no map for a shared source (t26, hu-mapper version 3).
- The compatibility check compares per-configuration flags and ABI definitions, also under Ninja Multi-Config (t04).
- hu-mapper: an unreadable source is reported and not cached; non-ASCII paths on Windows (t01).
- tools/update_release_branch.cmake passes update-ref the right old value. run-msvc.bat: ctest next to CMAKE_EXE, XFAIL for t02/t08/t11.
- Test driver: NINJA_JOBS (-D or environment) limits each test's ninja. tests/attack is removed.

Verified:
- Full Windows matrix at a7106a5 (CMake 4.5.0): win 25/25, clangcl 25/25, msvc 22 PASS + XFAIL t02/t08/t11, mingw 24 PASS + XFAIL t02.
- At f276251 (the t26 fix), targeted only: Linux GCC 16.2 t26, t25, t03, t12, t13, t15, t21, t23; win t26, t08, t15; clangcl, msvc, mingw t26; and t02, t04, t08 on win, clangcl, msvc, mingw, Linux gcc and Linux clang (PASS, or the known XFAILs).
- NOT run since b0fc455: the full Linux matrix (gcc, clang, libcxx; libcxx not at all), CMake 4.4.5, the MSBuild pass-through (run-msvc.bat). Run the full matrix once: `release` already holds this code.

Open work, in the order planned:
1. Dead and duplicate code, no behaviour change (not started; an audit's findings, verify each by reading): (a) `_HU_SET_<set>_MAPLINES` is written in Core.cmake and never read, with code in GCC.cmake and Core.cmake that only feeds it; (b) the `_hu_<toolchain>_finish_set` hook is empty in all three toolchains; (c) the "header contains an import" check and message are twice in Core.cmake; (d) `_hu_search_base` reads CMAKE_CXX_FLAGS twice and records the self-check settings twice; (e) "write a file only when its content changed" is repeated in Clang.cmake, MSVCNinja.cmake and GCC.cmake. Check: run t02, t04, t08 before and after and compare the build trees' build.ninja, *.map, *.rsp and hu-index.txt byte for byte (same checkout path both times).
2. The owner's decisions, asked and not yet answered (the owner wants less code; estimates from the audit): remove HU_ALLOW_HEADER_IMPORTS (experimental, ~190 lines, t10)? remove the HU_GCC_WRAPPERS fallback (~130 lines; the owner asked for it as the cross-compile fallback)? remove hu-mapper's own import scan and cache (~480 lines; CMake's scan stays; costs ~1.5 s per reconfigure at 1000 sources)? are Ninja Multi-Config (~75 lines, t23) and target_header_units_scan_sources (~40 lines, t15) used?
3. README: the Results section is history (several dated paragraphs and an old table); replace it by one short table from the next full matrix.
4. Suspected, not reproduced: MSVC with Ninja, a module interface unit compiled by two targets of one directory: the per-target interface options (the header units an importer of the module needs) are set only for the first target, because the toolchain macro runs once per (directory, source). Idea: set them in _hu_MSVC_consumers_done over Core.cmake's TUs.
5. Known and left: Common.cmake compares CMAKE_CXX_FLAGS as whole strings, so a subdirectory that only adds -Wall fails the compatibility check; _hu_search_base ignores per-configuration flags under Ninja Multi-Config; MSVC with a non-ASCII build directory fails the configure self-check (cl prints /showIncludes in the console code page); HU_GCC_WRAPPERS with a build directory outside the ANSI code page fails; Auto.cmake and Common.cmake collect a target's sources by different rules (default module file set, generator expressions, build-directory fallback), unchecked which is right.

Learned while testing:
- On a 16 GB machine, four suites at once froze it: one toolchain at a time, e.g. JOBS=2 NINJA_JOBS=5; Linux and Windows runs not at the same time.
- `wsl -d <distro> -- bash script.sh "t01;t02"`: the ; ends the command that wsl.exe hands to the shell (exit 127, "t02: command not found"); pass commas and turn them into ; inside the script.
- t26 on Linux GCC only fails without the fix when the two targets spell the include directory the same way; MinGW always.
