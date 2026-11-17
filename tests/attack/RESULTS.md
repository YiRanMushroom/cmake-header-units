# Adversarial scenarios (tests/attack): results

Run on 2026-11-17 with CMake 4.5.0, fresh build dirs, `tests/attack/run_attack.cmake` (wrappers: `run-attack-win.bat`, `run-attack-linux.sh`).
Module under test: `cmake/HeaderUnits.cmake` sha256 `cb4b158da1bef3a0b1a46c6af79f48f1fd3b0e064f2cf1bcb247090cbae40885` (repo HEAD `fc1755c9`, the module's last commit is 2026-11-17 15:16 -0700). All three runs used this version, and it did not change during any run (the driver hashes it at start and end); it still had this hash after the runs.
Note: the module is being edited in parallel, so these findings apply to this version only.
Toolchains:
- gcc: GCC 16.2 + libstdc++, container hu-dev.
- clang: Clang 22.1.8 + libstdc++ 16 (`--gcc-toolchain=/usr/local`), container hu-dev.
- win: Clang 22.1.8 GNU driver + MSVC STL 14.44, Windows.

Raw tables are in `_build/attack-<tc>/results.txt` and full logs in `_build/attack-<tc>/logs/<variant>.log`. The Linux copies were pulled back from the container's `/work/attack/_build`.

Verdicts:
- PASS: as expected (build + run + no-op).
- EXPECTED-ERROR: the expected clear configure error (regex-matched), or for a04 a loud build/link failure of a deliberately mismatched target.
- FAIL: deviates from the README's EXPECTED line.
- SKIPPED: the variant is not applicable to that toolchain.

| variant | gcc | clang | win | evidence (short) |
|---|---|---|---|---|
| a01_n25 | PASS | PASS | PASS | 25 HUs in one TU |
| a01_n35 | PASS | PASS | **FAIL** | win: `The command line is too long.` (scan step) |
| a01_n60 (original) | PASS | PASS | **FAIL** | win: same; FLAGS line 15263 chars |
| a01_n250 | PASS | PASS | **FAIL** | win: `ninja: fatal: CreateProcess: The parameter is incorrect.` |
| a01_stl (~80 STL HUs) | PASS | PASS | **FAIL** | win: `The command line is too long.` |
| a02_crossdir | **FAIL** | PASS | PASS | gcc: after the 41->42 edit, a02_synth exits 100 (stale mx@synth BMI) and the next ninja is not a no-op; clang/win: all three exes return 42 after one ninja |
| a03_shared_src | **FAIL** | **FAIL** | **FAIL** | a03_d1=0; a03_d2 does not build (clang/win: `<tiny3/t3.hpp> ... cannot be imported because it is not known to be a header unit`; gcc: `failed to read compiled module`) |
| a04_runtime | **FAIL** | **FAIL** | EXPECTED-ERROR | the original three targets (a04_ok, a04_rt, a04_idl) exit 0 on Linux; the Linux FAIL comes only from the port-added a04_gdbg (-D_GLIBCXX_DEBUG), which exits 3, `imported sizeof(vector<int>)=24 / textual 56` (silent); win: a04_rt/a04_idl fail at link with `lld-link: /failifmismatch: mismatch detected for '_ITERATOR_DEBUG_LEVEL'` (not caught at configure); controls exit 0 |
| a05_features | **FAIL** | PASS | PASS | gcc: configure error `consumer CXX_STANDARD='cstd-NOTFOUND' but the set was built with CXX_STANDARD=20` |
| a05_extoff | PASS | PASS | PASS | |
| a06_longpath | PASS | PASS | PASS | 255-char object path |
| a07_space | EXPECTED-ERROR | PASS | PASS | gcc: `with GCC the build directory must not contain spaces` |
| a07_space_gcchdr | EXPECTED-ERROR | SKIPPED | SKIPPED | gcc: `<sp/sp.hpp> resolves to '.../vendor dir/include/sp/sp.hpp' (contains a space)` |
| a08_junction (original) | **FAIL** | **FAIL** | **FAIL** | clang/win: a08_junc and a08_dotdot fail because of bug 1 (the same header in two sets); gcc: a08_junc and a08_junc2 fail (`failed to read compiled module`) |
| a08_single (one set) | **FAIL** | PASS | PASS | clang/win: both spellings work through link and '..'; gcc: a08_junc (consumer through the symlink) fails with `failed to read compiled module` |
| a09_lifecycle | **FAIL** | PASS | PASS | gcc: after deleting `vector.gcm`, ninja does not rebuild it and the scans fail with `failed to read compiled module`; the later steps (clean, touch CMakeLists.txt) therefore did not run on gcc |
| a10_order (original) | EXPECTED-ERROR | **FAIL** | **FAIL** | gcc: `<vector> ... is already a header unit of set 'hu_vs'`; clang/win: probes impvec_incstring_sameset, impvec_impstring, gmf fail (bug 1) |
| a10_oneset | PASS | PASS | PASS | every order probe compiles (8 probes; win also both windows.h orders) |
| a11_two_sets | EXPECTED-ERROR | **FAIL** | **FAIL** | gcc: `<vector> ... is already a header unit of set 'hu_a'`; clang/win: a11 fails on a.cpp `<vector>` and b.cpp `<string>` (bug 1); a11_fmt=0 |
| a11_fmtonly | PASS | SKIPPED | SKIPPED | fmt + `<string>` from two sets |
| a12_unity_pch | PASS | PASS | PASS | unity + PCH targets build and run |
| r01_dup_header (minimal repro) | EXPECTED-ERROR | **FAIL** | **FAIL** | clang/win: `<vector> ... cannot be imported because it is not known to be a header unit` |

Every PASS also includes a no-op second `ninja` (`ninja -n -d explain` reports no work).
The a09 steps were chosen by the porter (no original driver): re-run cmake, delete a BMI, `ninja clean`, touch CMakeLists.txt.
After re-running cmake, the first ninja re-collates the dyndep files, because CMake rewrites CXXDependInfo.json. The driver accepts that as long as nothing is recompiled.
Control run without the module (a plain C++20 project, CMake 4.5.0 in hu-dev): after re-running cmake, `ninja -n -d explain` shows the same `CXX.dd older than most recent input .../CXXDependInfo.json` (g++: `@cmake_cxx_std@synth_0`, clang: `c.dir`). This is CMake behaviour.

## Update 2026-11-17: after the fixes (CMake 4.5.0, fresh build dirs)

All six confirmed module bugs below are fixed; every scenario now behaves as expected:

| scenario | gcc | clang | win |
|---|---|---|---|
| a01 N=25 / 35 / 60 / 250 / STL | PASS | PASS | PASS (all; was FAIL from N=35: Clang options now in a per-source response file) |
| a02_crossdir | PASS (was FAIL: synthesized BMI now rebuilt in the same run) | PASS | PASS |
| a03_shared_src | PASS (was FAIL) | PASS (was FAIL) | PASS (was FAIL) |
| a04_runtime | FAIL (a04_gdbg, `_GLIBCXX_DEBUG` on the consumer only: not checked, documented) | FAIL (same) | EXPECTED-ERROR (link-time `/failifmismatch`) |
| a05 features / extoff | PASS (was FAIL) / PASS | PASS / PASS | PASS / PASS |
| a06_longpath | PASS | PASS | PASS |
| a07_space (+ gcc header variant) | EXPECTED-ERROR (both) | PASS | PASS |
| a08_junction / a08_single | FAIL / FAIL (GCC: symlinked include dir, documented) | PASS (was FAIL) / PASS | PASS (was FAIL) / PASS |
| a09_lifecycle | PASS (was FAIL: the CMI is now the object file) | PASS | PASS |
| a10_order / a10_oneset | EXPECTED-ERROR / PASS | PASS (was FAIL) / PASS | PASS (was FAIL) / PASS |
| a11_two_sets (+ gcc fmtonly) | EXPECTED-ERROR, PASS | PASS (was FAIL) | PASS (was FAIL) |
| a12_unity_pch | PASS | PASS | PASS |
| r01_dup_header | EXPECTED-ERROR (GCC: one header unit per header) | PASS (was FAIL) | PASS (was FAIL) |

Fixes (cmake/HeaderUnits.cmake): (1) Clang module names and module maps derive from the header path and a second set
in the same directory reuses the OBJECT_NAME, so per-directory source properties no longer depend on the set;
(2) consumer source properties are applied once per (target directory, source); (3) Clang header-unit options go into a
per-source response file; (4)+(5) GCC: `-fmodule-only` makes the CMI the set's object file (a real Ninja output), and
mapper files spell it relative to the build dir (`$root .`), so depfiles name the same Ninja node; (6) the consumer's
effective standard (CXX_STANDARD, else the compiler default, raised by compile features of the target and its link
interface) is compared instead of the raw CXX_STANDARD property.

The original run follows.

## Confirmed module bugs (against sha256 cb4b158d...)

1. **Clang: the same header in two sets of one directory breaks the earlier set.**
   - Repro: `tests/attack/r01_dup_header`. It also breaks the original a08, a10 and a11 on clang and win.
   - Observed: the consumer of `hu_one` fails with `header file <vector> ... cannot be imported because it is not known to be a header unit`.
   - Root cause (the code is still present in the hashed version): in build.ninja, the PCM compile of `hu_one.dir/hu/vector.o` carries `-fmodule-name=hu_two__vector`, while the consumer passes `-fmodule-file=hu_one__vector=...`. `set_source_files_properties(<header> TARGET_DIRECTORY <set> ...)` is directory-scoped and keyed by file, so the last set's COMPILE_OPTIONS and OBJECT_NAME win.
   - Expected: README/t04 allow one header in several sets on Clang, as long as no TU receives both. So either it builds, or it fails at configure time.

2. **One source in two targets from different directories gets header-unit flags only in the first directory (all toolchains).**
   - Repro: `tests/attack/a03_shared_src`.
   - Observed: a03_d1 builds and returns 0. a03_d2 fails: clang/win `not known to be a header unit`, gcc `failed to read compiled module`.
   - Root cause: `_hu_finalize` applies `set_property(SOURCE ... TARGET_DIRECTORY <first target>)` and then does `if(prev) continue()` for the second target. Source properties are per directory.
   - Expected: build OK. The README only rejects one source with *different* sets.

3. **Windows: a TU with more than ~30 header units cannot be scanned.**
   - Repro: `tests/attack/a01_cmdline -DA01_N=35`.
   - Observed: `The command line is too long.` CMake's Windows `CXX_SCAN` rule runs `cmd.exe /C "clang-scan-deps ... $FLAGS"`, which has an 8191-character limit.
   - Each header unit adds about 250 characters of per-source flags (`-fmodule-map-file=<abs path>` plus `-fmodule-file=<id>=<pcm>`); 60 headers gave a 15263-character FLAGS line.
   - Measured: N=25 OK, N=35 fail; N=250 also exceeds CreateProcess's 32K limit. The STL variant (~80 STL headers) fails too.
   - Expected: build OK. Not documented.

4. **GCC: a deleted or missing CMI is never rebuilt.**
   - Repro: `tests/attack/a09_lifecycle`, step "delete BMI".
   - Observed: build.ninja has `build CMakeFiles/header_units/gcm/.../vector.gcm: phony CMakeFiles/hu_std.dir/hu/vector.o`, so the OBJECT_OUTPUTS CMI is only a phony alias of an up-to-date .o.
   - After `rm vector.gcm`, ninja runs the consumer scans directly, and they fail with `failed to read compiled module: No such file or directory`.
   - Clang and win rebuild the deleted PCM correctly.

5. **GCC: the synthesized BMI of a cross-target named-module importer (Kitware #28166) is stale after a header-unit rebuild.**
   - Repro: `tests/attack/a02_crossdir`.
   - Observed: after a same-size edit 41->42 of `tiny2/detail.hpp` and one `ninja`, a02_plain and a02_hu return 42, but a02_synth returns 100 (mismatch).
   - The next ninja is not a no-op: `mx@synth_0.dir/....bmi.ddi older than most recent input /work/.../CMakeFiles/header_units/gcm/.../tiny.hpp.gcm`.
   - Likely cause: the synth target has no OBJECT_DEPENDS and sees the CMI only through its depfile, which spells the CMI path absolute. That is a different Ninja node from the relative `CMakeFiles/header_units/gcm/...` node; see also bug 4.
   - Expected: one ninja suffices, as on clang and win. The README listed this case as "not separately tested".

6. **GCC: configure error for `target_compile_features(cxx_std_20)` consumers; judged a false positive from a probe, not a build.**
   - Repro: `tests/attack/a05_compat -DA05_MODE=features`.
   - Observed: `consumer CXX_STANDARD='cstd-NOTFOUND' but the set was built with CXX_STANDARD=20`.
   - A CMake probe shows that with g++ 16, `CXX_STANDARD` stays unset (`CMAKE_CXX_STANDARD_DEFAULT=20`), while with Clang 22 CMake reports 20 (default 17). That is why only GCC trips.
   - The false-positive call is inferred: the gcc consumer was never built, because configure stops first. Its default standard, gnu++20, equals the set's. On clang and win the same project builds and runs.
   - `_hu_check_compat` compares the raw property. It should treat unset plus a satisfied compile feature or the default standard as equal.

## Undiagnosed mismatches / limitations (not counted as bugs)

These are missing diagnostics judged against the porter's expectations, not functional bugs with a valid configuration.

7. **Compile-definition mismatches between set and consumer are not checked and can be silent (ODR violation).**
   - Repro: `tests/attack/a04_runtime`, target a04_gdbg.
   - Observed on Linux gcc and clang: a consumer with `-D_GLIBCXX_DEBUG` importing a set built without it compiles and links. At run time `sizeof(std::vector<int>)` is 24 through the header unit and 56 textually (exit 3).
   - On win, MSVC_RUNTIME_LIBRARY / `_ITERATOR_DEBUG_LEVEL` mismatches are caught only by the linker (`/failifmismatch`), not at configure time.
   - Expected: a configure-time error, or at least a documented limitation.

8. **GCC: a consumer that reaches the header through a different directory spelling (symlink/junction) fails at build time, with no configure-time diagnostic.**
   - Repro: `tests/attack/a08_junction -DA08_SINGLE=ON`, target a08_junc, Linux symlink.
   - Observed: `<build>-junction/jt/jt.hpp: error: failed to read compiled module`. GCC keys header units by path string. The failure is loud, but the README only documents the `"../x.h"` spelling case.
   - Clang and win handle the link and `..` spellings (a08_single PASS).

## Port notes
- Projects were copied unchanged except these porter additions, each marked "port" in the source:
  - a04: a portable IDL macro plus the `a04_gdbg` target (libstdc++ analogue).
  - a08: a symlink on non-Windows; the `A08_SINGLE` option.
  - a10: the `A10_ONE_SET` option.
  - a11: the `A11_NO_DUP` option.
  - r01: new minimal repro.
- The module path stays `${CMAKE_CURRENT_SOURCE_DIR}/../../../cmake`, which resolves to the repo's `cmake/` from `tests/attack/<scenario>`.
- a08 creates `<build>-junction`, a link into `tests/attack/a08_junction/vendor/include`. The driver never deletes it. Remove it only with `rmdir` (Windows) or `rm` on the link itself, never recursively.
