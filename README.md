# HeaderUnits.cmake: external headers as C++20 header units with CMake + Ninja (prototype)

## 仓库说明 / Quick start

```
cmake/HeaderUnits.cmake   模块本体（include(HeaderUnits)）
tests/                    t01–t07 测试工程 + 测试驱动 run_suite.cmake
run-linux.sh              Linux：GCC 16 与 Clang 22(+libstdc++) 跑全部测试
run-win.bat               Windows：clang++（MSVC STL）跑全部测试
docker/                   开发时用的 Linux 工具链镜像（GCC 16、Clang 22、fmt/json/Boost）
docs/REPORT.md            调研报告（CMake 官方态度、三家编译器实测、前人方案、路线）
```

Windows 测试需要 fmt 10.1.1 与 nlohmann_json 3.11.3 源码（只用头文件）：

```
git clone --depth 1 --branch 10.1.1 https://github.com/fmtlib/fmt.git ext-src/fmt
git clone --depth 1 --branch v3.11.3 https://github.com/nlohmann/json.git ext-src/nlohmann_json
```

This module turns **external** headers into C++20 header units. That covers standard library headers
(<vector>, <string>, <iostream>, ...) and third-party headers (<fmt/format.h>, <nlohmann/json.hpp>,
<boost/...>). Code built by CMake can then consume them with `import <...>;`, side by side with CMake's
native named modules (`FILE_SET CXX_MODULES`).

Supported toolchains, all tested:

| id    | compiler | standard library | host |
|-------|----------|------------------|------|
| gcc   | GCC 16.2.0 (`g++`) | libstdc++ 16 | Linux (container `hu-dev`) |
| clang | Clang 22.1.8 (`clang++-22 --gcc-toolchain=/usr/local`) | libstdc++ 16 | Linux (container `hu-dev`) |
| win   | Clang 22.1.8 (`clang++`, GNU-style driver, x86_64-pc-windows-msvc) | MSVC STL 14.44 | Windows |

Generator: **Ninja** (single-config) only. CMake: **4.5.0** and **4.4.5** (the module needs >= 4.2 for
`OBJECT_NAME`). MSVC and clang-cl are rejected with a clear error. libc++ is out of scope and untested; it
is not detected.

## 更新（2026-11-17）：Clang 改为"延迟加载 + modulemap"方案；支持项目自己的头

**Clang 分支**（Windows MSVC STL、Linux libstdc++ 都适用）不再用急切加载的 `-fmodule-file=<pcm>`，改为 Buck2 式的延迟加载，而且去掉了存根：
- 每个头文件单元生成一个 modulemap：`module "<set>__<hdr>" { header "<真实头文件绝对路径>" export * }`。
- 编 BMI：仍然用 OBJECT 库，选项加上 `-fmodule-name=<id>`。编译时**不能**看到它自己的 modulemap，否则 Clang 22 产出的 pcm 会让使用方崩溃。
- 使用方（按源文件加）：`-fmodule-map-file=<map>`、`-fmodule-file=<id>=<pcm，写成相对构建目录的路径>`、`-fmodule-file-deps`、`-Wno-experimental-header-units -Wno-ambiguous-macro`。
- 效果：
  - 不管怎么拼写，只要 `#include` 或 `import` 解析到这个头文件，都会变成 import（相当于 include 翻译）。
  - pcm 只有真正用到它的 TU 才会读。
  - MSVC STL 上"先 #include 后 import / 加载了却没导入"之类的报错全部消失（t06 的 6 种顺序全部 OK）。

**项目自己的头（②）**：
- `LINK_LIBRARIES` 现在可以写工程内的普通目标，例如 `add_header_units(hu_own HEADERS mylib/api.h LINK_LIBRARIES mylib)`。查找头文件时会读取它的 `INTERFACE_INCLUDE_DIRECTORIES` 和 `INTERFACE_COMPILE_DEFINITIONS`；只支持普通路径和 `$<BUILD_INTERFACE:...>`，**不递归**处理它链接的库。
- 新增 `INCLUDE_DIRECTORIES <dirs>`，用于放在源码旁边的头，例如 `add_header_units(hu_local HEADERS local.h INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/app)`。使用方可以写 `import "local.h";`、`#include "local.h"`，Clang 下子目录里的 `"../local.h"` 也可以。

**实测（CMake 4.5.0 和 4.4.5，从头构建）**：t01–t07 在 gcc / clang(libstdc++16) / win(clang + MSVC STL) 上 **42/42 PASS**。另外核对了依赖文件：t07 子目录 TU 里的 `#include "../local.h"` 和 `#include <mylib/api.h>`，在 Clang 上都读的是 pcm，说明已被翻译成 import。

**新的已知限制：**
- **GCC**：带 `..` 的拼写（`#include "../local.h"`）不会被翻译，GCC 会静默退回文本包含（结果正确，但没提速）。显式写 `import "../local.h";` 在 GCC 上会报错（"unknown compiled module interface"）。原因是 GCC 拿原样路径当头文件单元的名字（PR 125337）。建议通过 include 路径来引用（`<app/local.h>` 这种形式）。
- **Clang**：命名模块接口里不带 export 的 `import <hdr>`，导入方看不到其中的定义（t03 探针），请用 `export import`。
- 原来的急切加载实现备份在 `cmake/HeaderUnits.cmake.v1.bak`。

## Usage

```cmake
cmake_minimum_required(VERSION 3.28...4.5)
project(app LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(HeaderUnits)              # top-level CMakeLists.txt, after project(), before add_subdirectory()

find_package(fmt REQUIRED)
add_header_units(hu_std HEADERS vector string iostream)
add_header_units(hu_fmt HEADERS fmt/format.h LINK_LIBRARIES fmt::fmt)

add_executable(app main.cpp util.cpp legacy.cpp)
target_link_libraries(app PRIVATE fmt::fmt)
target_import_header_units(app hu_std SOURCES main.cpp util.cpp)   # legacy.cpp: no header units
target_import_header_units(app hu_fmt SOURCES main.cpp)
```

```
add_header_units(<set> HEADERS <name>...
                 [LINK_LIBRARIES <imported-target>...]      # include dirs / definitions for the headers
                 [COMPILE_DEFINITIONS <def>...] [COMPILE_OPTIONS <opt>...]
                 [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>] [POSITION_INDEPENDENT_CODE <bool>])
target_import_header_units(<consumer> <set> [SOURCES <src>...])  # default: all C++ sources incl. CXX_MODULES file sets
```

* `<name>` is the header name as written in `import <name>;`.
* `<set>` becomes an OBJECT library target of that name. **Do not link it.**
* The set takes `CXX_STANDARD` / `CXX_EXTENSIONS` from `CMAKE_CXX_STANDARD` / `CMAKE_CXX_EXTENSIONS` unless they are given explicitly.
* Keep sets small and disjoint, and give each TU only the sets it imports (see the Clang/MSVC STL boundary below).
* Put imports before textual `#include`s.

### Auto-discovery: `target_auto_header_units`

```cmake
add_executable(app main.cpp util.cpp)
target_link_libraries(app PRIVATE mylib fmt::fmt)
target_auto_header_units(app)      # after the sources and target_link_libraries are set
```

```
target_auto_header_units(<target> [LINK_LIBRARIES ...] [INCLUDE_DIRECTORIES ...] [COMPILE_DEFINITIONS ...]
                         [COMPILE_OPTIONS ...] [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>]
                         [EXCLUDE <name>...] [NO_RECONFIGURE])
```

* Scans the target's C++ sources (including `CXX_MODULES` file sets) for `import <x>;` / `import "x";` (optionally
  `export import`). Every imported header becomes a header unit of the target. No header lists are needed.
* A header that already belongs to a set (declared with `add_header_units` or discovered for another target) is reused.
  The rest go into a new set `<target>_hu`, built with the target's direct target `LINK_LIBRARIES`, `INCLUDE_DIRECTORIES`
  and `COMPILE_DEFINITIONS` (plain values and `$<BUILD_INTERFACE:...>`), plus the extra values given.
* `import "x";` found next to the importing source is used by absolute path, like the compiler's quote lookup.
* The scanned sources become `CMAKE_CONFIGURE_DEPENDS`, so a new import re-runs CMake (`NO_RECONFIGURE` turns this off).
* Not considered (by design): imports produced by macros, and imports inside `#if`. An import inside a disabled `#if`
  only costs an unused BMI.
* A header unit whose header itself contains an import declaration is a configure-time error
  ("... not supported yet"), unless `HU_ALLOW_HEADER_IMPORTS` is ON (below).

### Experimental: header units that import header units (`HU_ALLOW_HEADER_IMPORTS`)

```cmake
set(HU_ALLOW_HEADER_IMPORTS ON)    # before add_header_units / target_auto_header_units
```

* Headers may then contain `import <x>;` / `export import "y.h";`. Each imported header must be a header unit of some
  set (`target_auto_header_units` adds them recursively). Imports within one set and across sets both work.
* The importing BMI is built after the imported BMIs and rebuilt when they change (touching `b.h` rebuilds b's BMI,
  then a's BMI, then the consumers). Consumers of a set also receive the sets it imports.
* GCC: the importing header's own mapper lists the imported headers. Clang: the importing header's compile gets the
  imported module maps and named `-fmodule-file=` options.
* Use `export import` in the header if the importer should see the imported declarations (on Clang a plain
  `import` inside a header unit is not re-exported).
* Tested by t10 on all three toolchains. Still experimental: cycles are not diagnosed, and headers that `#include` a
  header which is also a header unit elsewhere are not specially handled.

## Design

**1. Every BMI is built by CMake's own compile rule, so the flags are exact.** Each set is an OBJECT library.
Its sources are the resolved absolute header paths, with `LANGUAGE CXX`, a short `OBJECT_NAME` (`hu/<name>`) and
per-source options. That gives the header unit the same `CMAKE_CXX_FLAGS` (e.g. `--gcc-toolchain`),
`CMAKE_CXX_FLAGS_<CONFIG>`, `-std=gnu++20`/`c++20`, MSVC runtime flags, and include dirs/definitions of
`LINK_LIBRARIES` as the consumers. It also gets CMake's normal depfile handling. `CXX_SCAN_FOR_MODULES` is OFF for
the set (header units are not scanned).
* GCC: `-fmodules -fmodule-header -fmodule-mapper=<own map> -fdeps-format=p1689r5`. The CMI is declared as the
  source's `OBJECT_OUTPUTS` (`CMakeFiles/header_units/gcm/<set>/<abs path>.gcm`); the `.o` itself is empty.
  `-fdeps-format=p1689r5` is required. Without it GCC's `-MD` depfile contains module make rules
  (`<hdr>.c++-module`, `.PHONY`) that Ninja records as never-existing inputs, so every build rebuilds everything.
  This was observed and then fixed.
* Clang: `-fmodule-header=system -xc++-system-header` (this also handles extension-less names). The "object"
  CMake writes is the PCM.

**2. Name resolution at configure time.** One `try_compile` per set, using the set's
`LINK_LIBRARIES`/definitions/options/standard and the project's `CMAKE_CXX_FLAGS`, compiles one probe TU per header
with `-H`: `#include "<marker_i.h>"` then `#include <name>`. The first depth-1 header after the marker is the
file the compiler picked. GCC 16 prints normalized paths (`/usr/local/include/c++/16.2.0/vector`), which is exactly
the header-unit identity GCC uses for `import <vector>;`. The module fails if the GCC path is not normalized, contains a
space, or lies inside the build tree (CMake passes such sources as relative paths, which would change the
identity). Clang matches header units by file identity, so its path is canonicalized with
`file(REAL_PATH)`. The resolved list is printed at configure time and written to `CMakeFiles/header_units/manifest.txt`.

**3. Ordering.** There are two mechanisms.
* Every selected source gets its BMIs as `OBJECT_DEPENDS`. CMake's Ninja generator puts them on **both** the scan
  statement (`.ddi`) and the compile statement as explicit inputs. That is what makes the GCC scan (which must
  load the CMI) and `clang-scan-deps` (which needs the PCM named by `-fmodule-file`) wait for the BMIs, and what
  makes rebuilt BMIs rebuild the consumers.
* Every consumer also depends on a utility target `<set>_ready` (`build <set>_ready: phony <set>`, i.e. all BMIs).
  That puts the BMIs into the consumer's `cmake_object_order_depends_target_*` phony.

`add_dependencies(consumer <set>)` on the OBJECT library alone does **not** order anything: build.ninja showed only
`cmake_object_order_depends_target_<consumer>: phony || cmake_object_order_depends_target_<set>`.

The utility target matters for Kitware #28166. When an importer of a named module from another target has its
own target-level compile options, CMake synthesizes a separate BMI target `m@synth_N`. Measured: `-O2`, `-fPIC`,
`-std=...`, `-fno-strict-aliasing` and `-fmodule-file=...` trigger it; `-D...` and `-Wall` do not. That target
compiles `m.cppm` with the per-source header-unit flags but without `OBJECT_DEPENDS`. Before `<set>_ready`
existed, a fresh build of such a tree failed with GCC and Clang on Linux (Windows was not tried before the fix) with "module file '.../vector.o' not found" /
"failed to read compiled module". Now `cmake_object_order_depends_target_m@synth_N` reaches `<set>_ready` through
m's own order phony (t03, `T03_SYNTH`).

The driver checks in build.ninja, for every consumer TU, that the scan and the compile list all of its BMIs as
inputs and that the scan carries the same header-unit flags as the compile.

**4. Rebuilds.** The set's depfiles list every header the header unit includes. Any edit, including a same-size
edit, rebuilds the BMI. The BMI is an explicit input of the consumers, so they rebuild after it. The consumer
depfiles also list the CMIs/PCMs they read. A second `ninja` is a no-op. This is checked in t05 and after every
build.

**5. GCC module mapper.** Each consumer TU gets its own map file, `CMakeFiles/header_units/src/<abs src>.map`
(`<header path> <cmi>` lines for its sets).
* Scan: CMake's GCC scan rule passes no mapper. The per-source option
  `-fmodule-mapper=|g++-mapper-server -f - <tu map>` lets the scan load the CMIs. `-f` (fallback) is needed: with a
  plain file mapper, `import m;` of a named module is a fatal "unknown compiled module interface" even in `-E`
  mode. With the fallback, the scan simply never reads named-module CMIs.
* Compile: CMake appends `-fmodule-mapper=<tu>.modmap` after all user flags, and GCC uses only the last mapper.
  `CMAKE_CXX_MODULE_MAP_FLAG` is therefore overridden to
  `'-fmodule-mapper=|/bin/sh <build>/CMakeFiles/header_units/gcc-mapper.sh <MODULE_MAP_FILE> $in'`.
  `gcc-mapper.sh` execs `g++-mapper-server - <CMake modmap> [<tu map>]`, where `$in` (the source, a Ninja variable)
  selects the TU's map. TUs that were not selected get CMake's modmap only, exactly as without the module.
* Why not the default `gcm.cache` location that the task suggested? GCC turns `#include <x>` into an import
  whenever a CMI for `x` exists in the default location. Then any **unselected** TU in the tree, with no ordering
  edge to the CMIs, would read them or not depending on timing. With per-TU maps, unselected TUs never see the
  header units (t06: `excluded.cpp`'s depfile lists the textual `vector`).
* Isolation instead of header-unit-to-header-unit edges. Each header unit is compiled with a mapper that lists
  only itself, so GCC never translates the `#include`s inside it. The CMI does not depend on build order, and
  rebuilding one header unit cannot cause a "CRC mismatch" in another. Overlapping isolated header units merge
  when imported together: t02 `both.cpp` imports `<string>` and fmt, whose header includes `<string>`. t02 (GCC)
  builds the string and fmt CMIs in both orders and compares SHA-256 hashes. They are byte-identical with
  `SOURCE_DATE_EPOCH` set; without it GCC embeds a `buildtime:` string in every CMI. Rebuilding only `<string>`
  then still builds a TU importing both.
* One header unit per header per build tree: a second set declaring the same header is a configure error
  (t04 `T04_BAD=dup`).
* Importers of a named module whose interface imports header units need nothing extra: GCC loads the CMI path
  recorded in `m.gcm` (tested raw and in t03).

**6. Clang.** Selected sources get one `-fmodule-file=<pcm>` per header unit of their sets, plus
`-Wno-experimental-header-units`, as per-source `COMPILE_OPTIONS`. These options reach the
`clang-scan-deps` command. Because they are per source, the module never changes target-level flags and
never causes an `m@synth_*` BMI target itself (t03 checks build.ninja). Importers with their own target-level
options do get one (CMake behaviour); it stays correctly ordered (see 3). Clang has no include translation, so
isolation is automatic.

**7. Configure-time checks.** At the end of the top-level directory, every consumer is compared with its sets.
The configure fails with a clear message on:
* a different `CXX_STANDARD`, or `CXX_EXTENSIONS` (`c++20` vs `gnu++20`);
* a `cxx_std_NN` compile feature above the set's standard, or a `-std=` option;
* different `-f[no-]exceptions` / `-f[no-]rtti`;
* a different directory-level `CMAKE_CXX_FLAGS[_<CONFIG>]`;
* a missing mapper override in the consumer's directory (GCC);
* a TU that would receive two header units for one file;
* one source used by two targets with different sets.

A PIC mismatch is only a warning: both compilers accept it silently, and only `__PIC__`-dependent preprocessor branches
in the headers could differ.

## CMake internals used (unsupported; grep `CMAKE-INTERNAL` in cmake/HeaderUnits.cmake)

1. **`CMAKE_CXX_MODULE_MAP_FLAG` override (GCC).** This is CMake's private template for the mapper option of its
   scanned GCC compile rule. The module replaces `-fmodule-mapper=<MODULE_MAP_FILE>` and fails loudly if the
   string is not found. The string was found and replaced in both 4.4.5 and 4.5.0.
2. **Ninja variable `$in` injected into that template (GCC).** It relies on CMake writing compile sources as
   absolute paths, or as paths relative to the top build dir when they are inside it (the wrapper handles both).
3. **Clang PCM location.** The module assumes `<set binary dir>/CMakeFiles/<set>.dir/hu/<name><obj ext>`, i.e.
   CMake's default `CMAKE_INTERMEDIATE_DIR_STRATEGY=FULL` plus the public `OBJECT_NAME`. It needs this because
   `OBJECT_DEPENDS` does not accept `$<TARGET_OBJECTS>` (tried: the genex ends up literally in build.ninja). `SHORT`
   is rejected. If CMake moved the object, Ninja would stop with "missing and no known rule to make it", which is
   loud and never a silent misbuild.
4. **Observed Ninja-generator behaviour.** Per-source `COMPILE_OPTIONS` and `OBJECT_DEPENDS` are applied to the scan
   statement too, and CMake's GCC scan rule passes no mapper of its own. The driver re-verifies both in build.ninja
   on every run.

## Per-toolchain caveats and boundaries (measured, see tests/t06 and the t03 probe)

t06 probe TUs each receive the `<vector>` BMI:

| probe TU | gcc | clang (libstdc++) | win (MSVC STL) |
|---|---|---|---|
| `import <vector>; #include <string>` | OK | OK | OK |
| `#include <string>` then `import <vector>;` | OK | OK | FAIL: `cstdio:33: missing '#include <cwchar>'; '_Mbstatet' must be declared before it is used` |
| `#include <cstdio>` then `import <vector>;` | OK | OK | FAIL (same) |
| BMI loaded, only textual `#include <string>`, `<vector>` | OK | OK | FAIL (same) |
| `import <vector>; #include <vector>` | OK | OK | OK |
| `#include <vector>` then `import <vector>;` | OK | OK | FAIL: `xtr1common:177: unknown type name '_NODISCARD'` |

* **gcc:** an `#include` of a header that is in the TU's map is translated into an import; others stay textual.
  All orders work.
* **win (Clang + MSVC STL):** a TU that receives a PCM must import first and include afterwards, and must not
  receive PCMs it only includes textually. This is why selection is per source and sets should be small. The
  module cannot detect a wrong order, but the compiler fails loudly.
* **Clang (both):** a NON-exported `import <vector>;` inside a module interface does not make `std::vector`'s
  definition reachable for importers of that module:
  * Linux: `missing '#include <bits/stl_vector.h>'; 'vector' must be defined before it is used`
  * Windows: `definition of 'vector' must be imported from module '...\include\vector' before it is required`

  GCC accepts it. Use `export import <hdr>;` when the module's API exposes the header's types (t03), or import the
  header unit in the consumer as well.
* **win + fmt 10.1.1 header-only:** `format-inl.h` does not compile with Clang 22 ("call to consteval function
  ... is not a constant expression"), with or without header units. tests/common/ExternalLibs.cmake defines
  `FMT_CONSTEVAL=` for the Windows `fmt::fmt` target. This is a third-party issue.
* **GCC:** mapper files cannot contain spaces (source, header and build paths are checked). Headers inside the
  build tree are rejected. The wrapper is POSIX `sh` (GCC is Linux-only here). CMIs are not reproducible with `-g`
  unless `SOURCE_DATE_EPOCH` is set.
* **Clang:** every TU of a set receives all PCMs of that set (granularity: set x source).

## Tests

Each test is a standalone CMake project under `tests/`, with a one-line README saying what it proves.

| test | proves |
|---|---|
| t01_stl | `import <vector>/<string>/<iostream>` in a plain executable (no named modules) |
| t02_thirdparty | fmt + nlohmann_json (+ Boost.Optional on Linux) + STL header units in one TU; fmt without `<string>`; `<string>` + fmt overlap merge; GCC build-order independence |
| t03_named_modules | `FILE_SET CXX_MODULES` module with `export import <vector>`; exe doing `import m; import <string>; ...`; another target importing m, with no synthetic BMI target; `T03_SYNTH` tree: importer with target-level `-O2` (#28166), where CMake synthesizes `m@synth_N` and it builds correctly ordered; probe for a non-exported import |
| t04_shared_set | two targets share one set; `T04_BAD=std/ext/exc/dup` (CXX_STANDARD 23, CXX_EXTENSIONS OFF, `-fno-exceptions`, header in two sets) must fail at configure time with a clear message |
| t05_rebuild | no-op; touch a header included by the header unit; same-size edit 41->42 reaches the exe; touch the header unit's own header; `ninja -n -d explain` plus executed edges show the BMI rebuilt before the consumer |
| t06_mixed | header unit + overlapping textual `#include` in one TU; a TU excluded via SOURCES builds textually; boundary probes |
| t07_own_headers | the project's own headers as header units: an in-tree library header via `LINK_LIBRARIES mylib` (`$<BUILD_INTERFACE:...>`), a local header via `INCLUDE_DIRECTORIES`; `#include` of them in another TU is translated |
| t08_auto | `target_auto_header_units`: sets generated from the imports (STL, fmt, in-tree library header, `import "local.h"` by path); a second target reuses `<vector>` and gets a new set for `<string>` |
| t09_header_import_error | a header unit whose header contains `import <vector>;` is rejected at configure time with "not supported yet" |
| t10_header_imports | `HU_ALLOW_HEADER_IMPORTS ON`: `a.h` does `export import <vector>; export import "b.h";` (auto, recursive), manual set with intra-set and cross-set imports; touching `b.h` rebuilds b's BMI, then a's BMI, then main.cpp |

The driver `tests/run_suite.cmake` is a portable `cmake -P` script. For every test it runs:
* a fresh configure and build (`ninja`, parallel by default), then ctest;
* the no-op check;
* the build.ninja edge check: the scan and compile of every consumer depend on its BMIs, and the scan flags equal the compile flags;
* the **depfile evidence**: for every `import <x>;` in a consumer, `ninja -t deps` lists the BMI and does NOT list the header;
* a **negative check**: it moves the BMI away and runs the consumer's exact compile command (from `ninja -t commands`),
  which must fail and name the missing BMI. Examples: GCC `failed to read compiled module ... vector.gcm`, Clang
  `module file '.../hu_std.dir/hu/vector.obj' not found`;
* the test-specific steps.

How to run:
* Linux: `sh run-linux.sh` runs GCC and Clang (+libstdc++) in parallel with the `cmake` on PATH (`CMAKE_EXE=...` to choose;
  `CLANG_CXX` / `CLANG_FLAGS` default to `clang++-22` / `--gcc-toolchain=/usr/local`, matching `docker/Dockerfile`).
  Build on a native Linux filesystem; under WSL never build on `/mnt/c`.
* Windows: `run-win.bat` (clang++, ninja and cmake on PATH; it sets up the MSVC environment via vswhere unless it is
  already set; `CMAKE_EXE=...` to choose CMake). Needs `ext-src/` (see Quick start).
* Subset: `TESTS="t01;t05"`.

Results go to `_build/<tc>-<tag>/results.txt`, with full logs in `logs/<test>.log`.

## Results (final run, fresh build directories, 2026-11-17: 60/60 PASS)

| test | gcc / CMake 4.5.0 | gcc / 4.4.5 | clang+libstdc++ / 4.5.0 | clang+libstdc++ / 4.4.5 | win clang+MSVC STL / 4.5.0 | win / 4.4.5 |
|---|---|---|---|---|---|---|
| t01_stl | PASS | PASS | PASS | PASS | PASS | PASS |
| t02_thirdparty | PASS | PASS | PASS | PASS | PASS (no Boost on Windows) | PASS (no Boost on Windows) |
| t03_named_modules | PASS | PASS | PASS | PASS | PASS | PASS |
| t04_shared_set | PASS | PASS | PASS | PASS | PASS | PASS |
| t05_rebuild | PASS | PASS | PASS | PASS | PASS | PASS |
| t06_mixed | PASS | PASS | PASS | PASS | PASS | PASS |
| t07_own_headers | PASS | PASS | PASS | PASS | PASS | PASS |
| t08_auto | PASS | PASS | PASS | PASS | PASS | PASS |
| t09_header_import_error | PASS | PASS | PASS | PASS | PASS | PASS |
| t10_header_imports | PASS | PASS | PASS | PASS | PASS | PASS |

A PASS covers every driver step above. No configure log of the final run contains a `CMake Warning` (the PIC
warning did not fire). Recorded boundary probes, which do not affect the verdict:
* t06: see the table above.
* t03 non-exported import: gcc OK, clang FAIL, win FAIL.

Nothing is UNTESTED. The one gap: Boost is not available on Windows, so t02 there covers fmt + nlohmann_json + STL.

## Known limitations

* Prototype. It relies on the CMake internals listed above. Kitware considers ersatz header units unsupported.
* Single-config Ninja only. No install/export of header-unit sets. BMIs must stay where they were built (Clang
  records PCM paths, GCC records CMI paths in importing BMIs).
* In-tree `LINK_LIBRARIES` contribute only their own `INTERFACE_INCLUDE_DIRECTORIES` / `INTERFACE_COMPILE_DEFINITIONS`
  (plain values and `$<BUILD_INTERFACE:...>`), not those of their dependencies (non-recursive). IMPORTED targets are used as is.
* The compatibility checks look at target and directory properties. Language flags injected another way (for example
  a linked library's `INTERFACE_COMPILE_OPTIONS -std=...` or generator expressions) are not seen at configure time.
  The compilers still reject `-std`/exception/RTTI mismatches at build time.
* GCC: exactly one header unit per header per build tree; no spaces in paths; headers inside the build tree are rejected.
* Clang: `CMAKE_INTERMEDIATE_DIR_STRATEGY=SHORT` is rejected. A TU gets every PCM of its sets.
* The synthesized `m@synth_N` BMI (#28166 case) is ordered after the header units and builds. Its rebuild after
  an external-header edit relies on its depfile plus the order-only `<set>_ready` edge; this was not separately tested.
* PIC differences between a set and its consumers only produce a warning.
* Sources added via generator expressions must be listed with `SOURCES`. One source file used by several targets must
  get the same sets.
* CMake 4.4/4.5 also scan the `import std` sources (`@cmake_cxx_std@synth_0`) in every C++20 build. This is unrelated to
  this module; on Windows it prints many `std.ixx` warnings in the build log.
