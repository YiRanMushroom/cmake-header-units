# HeaderUnits.cmake

C++20 **header units** with CMake for **GCC, Clang and MSVC**, which CMake itself does not support yet. Add one module,
then write `import <vector>;`, `import <fmt/format.h>;` or `import "my/header.h";` instead of `#include` in your sources,
for the standard library, third-party libraries and your own headers. The same CMakeLists.txt also works with
**MSVC** and a Visual Studio generator: MSBuild builds header units natively, so the commands do nothing there; with
MSVC and Ninja the module builds them.

Status: prototype (November 2026). Tested with CMake 4.4.5 and 4.5.0 on:

| toolchain | generator | who builds the header units |
|---|---|---|
| GCC 16 + libstdc++ (Linux) | Ninja | this module |
| Clang 22 + libstdc++ 16 (Linux) | Ninja | this module |
| Clang 22 (`clang++`, GNU-style driver) + MSVC STL (Windows) | Ninja | this module |
| MSVC 19.44 (Windows) | Visual Studio 17 2022 | MSBuild (the commands do nothing) |
| MinGW-w64 GCC 16.1 + libstdc++ (Windows) | Ninja | this module |
| MSVC 19.44 (Windows) | Ninja | this module |

MinGW-w64 GCC is tested with CMake 4.5.0 and 4.3.1, MSVC with Ninja with CMake 4.5.0 (see Results).

Not supported: clang-cl, libc++, multi-config generators with GCC/Clang/MSVC-Ninja.

## Quick start

1. Get the module with FetchContent from the `release` branch, which holds only `cmake/` and the license (as in
   step 2), or copy `cmake/HeaderUnits.cmake` and the `cmake/HeaderUnits/` directory into your project. To work on
   the module itself, configure with `-DFETCHCONTENT_SOURCE_DIR_CMAKE_HEADER_UNITS=<a local checkout>`: FetchContent
   then uses that directory instead of downloading.
2. In the top-level `CMakeLists.txt`:

   ```cmake
   cmake_minimum_required(VERSION 3.28...4.5)
   project(app LANGUAGES CXX)
   set(CMAKE_CXX_STANDARD 20)

   include(FetchContent)
   FetchContent_Declare(cmake_header_units
     GIT_REPOSITORY https://github.com/YiRanMushroom/cmake-header-units.git
     GIT_TAG        release               # a branch or tag; for a commit hash, drop GIT_SHALLOW
     GIT_SHALLOW    TRUE)
   FetchContent_MakeAvailable(cmake_header_units)
   list(APPEND CMAKE_MODULE_PATH "${cmake_header_units_SOURCE_DIR}/cmake")
   # (with a copy instead: list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake"))
   include(HeaderUnits)                  # after project(), before any add_subdirectory()

   find_package(fmt REQUIRED)
   add_executable(app main.cpp util.cpp)
   target_link_libraries(app PRIVATE fmt::fmt)
   target_auto_header_units(app)         # anywhere after add_executable() in this CMakeLists.txt
   ```

3. In the sources:

   ```cpp
   import <vector>;
   import <fmt/format.h>;
   import "config.h";                    // found next to this source file
   ```

4. Configure and build:

   ```sh
   cmake -S . -B build -G Ninja -DCMAKE_CXX_COMPILER=g++     # or clang++
   cmake --build build
   # MSVC:
   cmake -S . -B build -G "Visual Studio 17 2022"
   cmake --build build --config Debug
   ```

What happens: at configure time the module scans the target's sources for import declarations and creates a header
unit for every imported header, compiled with the target's include directories, definitions and language settings.
The header units (BMIs) are built before the sources that need them and passed to the compiler. In those sources an
`#include` of the same header is served from the header unit too (Clang always; GCC when spelled the same way), so you
can switch from `#include` to `import` file by file.

To limit this to some sources, list them instead (their imports only; the target's other sources are untouched):

```cmake
target_header_units_scan_sources(app main.cpp)
```

For explicit control over which headers become header units and with which flags, declare sets:

```cmake
add_header_units(hu_std HEADERS vector string map)
add_header_units(hu_fmt HEADERS fmt/format.h LINK_LIBRARIES fmt::fmt)
target_import_header_units(app hu_std)                    # all C++ sources of app
target_import_header_units(app hu_fmt SOURCES main.cpp)   # only main.cpp
```

Requirements: GCC/Clang need CMake >= 4.2, the single-config **Ninja** generator and C++20 or later. MSVC needs CMake
>= 3.28 and a Visual Studio generator, or CMake >= 4.2, Ninja and MSVC 19.40 (Visual Studio 2022 17.10) or later, run
from a developer prompt.

## Commands

### target_auto_header_units

```
target_auto_header_units(<target> [LINK_LIBRARIES <tgt>...] [INCLUDE_DIRECTORIES <dir>...] [COMPILE_DEFINITIONS <def>...]
                         [COMPILE_OPTIONS <opt>...] [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>]
                         [EXCLUDE <name>...] [NO_RECONFIGURE])
```

* Scans the target's C++ sources (including `CXX_MODULES` file sets) for `import <x>;` and `import "x";` (also with
  `export`).
* A header that already belongs to a set is reused, whether it was declared or discovered for another target. Reuse
  is decided by the file the name resolves to with this target's include paths, not by the name: `<config.h>` from two
  different include directories gives two header units, `<vector>` (the same file) one. The others go into a new set
  `<target>_hu`. It is built with the target's own include directories, compile definitions, compile options (except
  warning options), link libraries (targets), standard and extensions, plus the values given here. Generator
  expressions in those properties are not copied (`$<BUILD_INTERFACE:...>` include directories are).
* The scan runs at the end of the `CMakeLists.txt` that calls the command (`cmake_language(DEFER)`), so the target's
  sources and settings may come after the command in the same file. A change made later from another directory, e.g.
  `target_link_libraries(<target> ...)` in a parent directory, is not seen; configure reports it with a warning.
* `import "x";` found next to the importing source is used by absolute path, like the compiler's quote lookup.
* The scanned sources become `CMAKE_CONFIGURE_DEPENDS`, so adding an import re-runs CMake. `NO_RECONFIGURE` turns this
  off.
* Only literal import declarations are recognized:
  * imports produced by macros are not;
  * imports inside `#if` are considered whatever the condition. A header that cannot be found with the target's include
    paths is skipped silently (e.g. a platform header in an inactive branch; shown with `--log-level=VERBOSE`). A header
    that exists but does not compile as a header unit in this configuration still fails the build;
  * sources added with generator expressions are not scanned.

### target_header_units_scan_sources

```
target_header_units_scan_sources(<target> <src>... [same options as target_auto_header_units])
```

The same as `target_auto_header_units`, but only for the listed sources:

* only they are scanned for imports, and only they receive header units. The target's other sources are left alone:
  their `#include`s stay textual, and an `import` in them does not compile;
* paths are relative to the current source directory. A file that is not a C++ source of the target is a
  configure-time error;
* it can be called several times for one target: headers that already have a header unit are reused, the rest go into
  `<target>_hu`, `<target>_hu_2`, ...;
* only the listed sources become `CMAKE_CONFIGURE_DEPENDS`.

### add_header_units

```
add_header_units(<set> HEADERS <name>... [LINK_LIBRARIES <tgt>...] [INCLUDE_DIRECTORIES <dir>...]
                 [COMPILE_DEFINITIONS <def>...] [COMPILE_OPTIONS <opt>...]
                 [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>] [POSITION_INDEPENDENT_CODE <bool>])
```

* `<name>` is the header as written in `import <name>;`. It is resolved in the search list the compiler uses for the
  set's target, first match: its `-I` directories (with those of `include_directories()` and
  `CMAKE_INCLUDE_CURRENT_DIR`), then `-isystem` ones such as an imported target's, then the compiler's own. The
  compiler reports its own list (`<compiler> <flags> -x c++ -E -v`) once per distinct set of options, with two marker
  directories where CMake puts a target's `-I` and `-isystem` directories; a target's list is that list with its own
  directories in their places. So the number of compiler runs follows the number of distinct option sets (usually
  one to three), not the number of targets; configure prints it. Nothing is compiled at configure time. A
  configure-time self-check (one more run, with the options of the first lookup) stops the configure if the compiler
  finds or names headers otherwise than this predicts; if its probe cannot run, it only warns. A header found only through a directory given as an unevaluable generator expression is not found:
  pass that directory with `INCLUDE_DIRECTORIES`.
* `LINK_LIBRARIES` supplies include directories and definitions, from imported or in-tree targets. In-tree link
  interfaces are followed recursively: ALIAS targets are resolved, private (`$<LINK_ONLY:>`) dependencies are not
  followed.
* `<set>` becomes an OBJECT library target of that name whose "objects" are the BMIs. **Do not link it.**
* `CXX_STANDARD` and `CXX_EXTENSIONS` default to `CMAKE_CXX_STANDARD` and `CMAKE_CXX_EXTENSIONS`.
* Headers inside the build tree work, e.g. FetchContent's `_deps/` or `configure_file` output. Headers generated at
  *build* time do not.

### target_import_header_units

```
target_import_header_units(<target> <set> [SOURCES <src>...])
```

Gives the set's header units to all C++ sources of the target, or only to the listed ones.

* The consumer's language settings must match the set's: C++ standard, extensions, exception and RTTI options,
  `CMAKE_CXX_FLAGS`, and definitions that change the C++ library's ABI (`_GLIBCXX_DEBUG`, `_GLIBCXX_USE_CXX11_ABI`,
  `_LIBCPP_ABI_*`; with the MSVC STL `_ITERATOR_DEBUG_LEVEL`, `_HAS_ITERATOR_DEBUGGING`, `_SECURE_SCL`,
  `_HAS_EXCEPTIONS` and `MSVC_RUNTIME_LIBRARY`) from the target, its directory and its link interface. This is checked
  at configure time.
* A source used by several targets, in any directories, must get the same sets.

### HU_ALLOW_HEADER_IMPORTS (experimental)

By default, a header unit whose header contains an import declaration is a configure-time error ("not supported
yet"). With `set(HU_ALLOW_HEADER_IMPORTS ON)`, set before the commands, headers may `import` or `export import` other
header units:

* `target_auto_header_units` discovers them recursively;
* imported BMIs are built first, and a change to them rebuilds the importers;
* cycles are not diagnosed.

### Keeping a source's `#include`s textual

```cpp
// HeaderUnits pragma: textual-includes
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
```

A source containing the comment `HeaderUnits pragma: textual-includes` receives only the header units of its own
`import` declarations (and of what those headers import). Every other `#include` in it stays textual, so macros
defined before the include take effect. Use it for the one source of an stb-style single-header library that defines
`XXX_IMPLEMENTATION`. A marked source with no imports compiles as a plain source.

* It is a comment, not a `#pragma`: GCC and Clang warn about an unknown `#pragma` with `-Wall`, MSVC by default
  (C4068). The compiler does not need to understand it; CMake reads it at configure time. In auto mode, editing the
  source re-runs CMake; with `target_import_header_units`, re-run CMake after adding or removing it.
* MSVC/MSBuild ignores it.

## Guidelines

* **Import in sources, include in headers.** This is the default. In a source that receives header units, the
  `#include`s in your headers are served from the BMIs anyway.
* **Module interfaces:** when a module's exported API uses a header's types, write `export import <hdr>;` in the
  module, or import the header in the consumer as well. Clang requires it and GCC does not, because the standard leaves
  it unspecified whether a header unit imported only by a module is reachable from that module's importers.
* **ABI-changing definitions** such as `_GLIBCXX_DEBUG` or the MSVC runtime and iterator debug level must reach the set
  too; directory-wide definitions do. By the standard, definitions on a consumer do not affect a header unit it
  imports, and a difference that exists only on the consumer is not detected.
* **GCC:** a header can be in only one set per build tree. A `#include` that reaches it by another path than the
  consumer's include path (`#include "../x.h"`) stays textual.

## How it works

**Common to GCC and Clang** (`cmake/HeaderUnits/Core.cmake`, `Common.cmake`, `Auto.cmake`):

* Each set is an OBJECT library that compiles its headers as header units with CMake's own compile rule, so a BMI gets
  exactly the flags CMake gives that target. The BMI is the object file.
* Consumers get per-source options plus `OBJECT_DEPENDS` on the BMIs. CMake applies both to the dependency-scan
  statement and to the compile statement of the source, so the BMIs are built before CMake's own module scan.
* A `<set>_ready` target orders the BMI targets that CMake synthesizes for cross-target named-module imports.
* Everything happens at configure time: targets, source properties, mapper files and the header lookup (one
  `-E -v` compiler run per distinct set of options, about 0.1 s each, plus the self-check). A deferred call finalizes
  after all CMakeLists have run. The header units themselves are compiled at build time, by Ninja.
* BMI paths are spelled relative to the build directory, so compiler depfiles name the same Ninja nodes and an edit
  rebuilds everything that depends on it in one `ninja` run.

**GCC** (`cmake/HeaderUnits/GCC.cmake`):

* A header unit is identified by the header's real path. GCC names it by its own spelling of the path, which the
  mapper is keyed by. Each mapper file is written from its compile's own search list: the spelling of the directory
  where that compile finds the header (an `-I` directory as given: GCC on Linux keeps `dir/../inc/x.h`; system
  directories, and everything on Windows, normalized), the normalized path and the real path (a symbolic link), all
  for the same BMI. So a consumer that spells an include directory differently from the set gets its own spelling.
* Each BMI is built with `-fmodule-only` through `hu-mapper`, a small mapper program (`cmake/HeaderUnits/hu-mapper.cpp`,
  GCC's libcody protocol) that configure builds once per build tree with the project's compiler. It gives GCC the BMI
  to write and keeps every `#include` in the header textual, so BMIs do not depend on build order. That includes an
  `#include` of the header itself, through another one (fmt's `core.h` includes `"format.h"` when header-only):
  GCC's own file mapper answers "where to write the BMI" and "is this `#include` a header unit" from the same entry,
  so GCC imported the header unit it was building (a Ninja dependency cycle, then "depends on itself" once the BMI
  existed); `hu-mapper` answers the latter with "textual" for the header being built.
* Cross-compiling, `hu-mapper` is built by a host compiler (`HU_HOST_CXX`, else `c++`, `g++` or `clang++` on the host's
  `PATH`) and kept if it runs. Without one (or with `HU_GCC_WRAPPERS` ON), each header unit is compiled from a
  generated wrapper whose only line is `#include "<header>"`, and its own mapper lists only the wrapper: the same
  effect without a program (GCC does not check a header unit's name when it reads the BMI, so consumers still name the
  header). Debug information is the same either way (the wrapper only adds an include level, no code).
* Each consumer source gets a mapper (`g++-mapper-server`) listing its header units. GCC also translates `#include`s of
  listed headers into imports.
* CMake's internal `CMAKE_CXX_MODULE_MAP_FLAG` is overridden so the compile serves CMake's named-module map and the
  header-unit map together.
* Headers inside the build tree (FetchContent dependencies, `configure_file` headers) need nothing special: `hu-mapper`
  answers the export whatever name GCC uses (CMake passes such a source relative to the build directory).
* On Windows (MinGW-w64) there is no `/bin/sh`, so the consumer mapper is a generated `gcc-mapper.cmd` run through
  `cmd /c`; it finds the source's map in `src-index.txt`. Mapper files get short hashed names, because paths past 260
  characters do not open, and `\n` line ends, because GCC's mapper-file reader takes a `\r` as part of a word.

**Clang** (`cmake/HeaderUnits/Clang.cmake`) uses lazy, named header units (the Buck2 scheme):

* A module map declares the real header as the only header of a module, and the BMI is built with `-fmodule-name`.
* Consumers get `-fmodule-map-file` and `-fmodule-file=<name>=<bmi>` in a per-source response file. Any `#include` or
  `import` that resolves to the header becomes an import, in any order, and a BMI is only read by sources that reach
  its header.
* The response file keeps command lines short: CMake runs the dependency scan on Windows through cmd.exe, which
  allows at most 8191 characters.

**MSVC with a Visual Studio generator** (`cmake/HeaderUnits/MSVC.cmake`):

* CMake marks C++20 sources for module scanning and MSBuild builds the header units of their imports itself.
* The commands check their arguments, keep scanning on and otherwise do nothing.

**MSVC with Ninja** (`cmake/HeaderUnits/MSVCNinja.cmake`):

* A header unit is identified by the header's resolved path. Its IFC is built with `/exportHeader /ifcOnly` and written
  as the set's object file, so it is a real Ninja output.
* Each consumer source gets `/headerUnit "<header>=<ifc>"` for its header units in a per-source response file.
  `/translateInclude` is added to CMake's module-map option of the compile rule, not per source: CMake's dependency scan
  gets the per-source options too, and `cl /scanDependencies` with `/translateInclude` recurses without end into a header
  that includes itself through another one.
* The header lookup assembles the include search list from the target's `/I` and `/external:I` directories, those in
  `CMAKE_CXX_FLAGS` and the compile options, and the `INCLUDE` environment variable; `cl` cannot print it. The
  self-check verifies it with `/showIncludes`.
* An importer of a named module whose interface imports header units needs those header units too (`cl` looks them
  up when it reads the module's IFC): the module's target gets them in its `INTERFACE_COMPILE_OPTIONS`, without
  `/translateInclude`.

**CMake internals relied upon** (unsupported; grep `CMAKE-INTERNAL` in `cmake/`):

1. GCC: the `CMAKE_CXX_MODULE_MAP_FLAG` override, with Ninja's `$in` injected into it. The module stops with an error if
   a CMake release changes the template. On Windows the override also names CMake's module map as `$out.modmap`
   (observed: the object path plus `.modmap`), since CMake spells `<MODULE_MAP_FILE>` with backslashes there.
2. The object location `<set binary dir>/CMakeFiles/<set>.dir/<OBJECT_NAME><ext>`, i.e. the default
   `CMAKE_INTERMEDIATE_DIR_STRATEGY` (`SHORT` is rejected). If CMake moved objects, Ninja would stop with "missing and no
   known rule": a loud failure, never a silent misbuild.
3. Observed Ninja-generator behaviour: per-source `COMPILE_OPTIONS` and `OBJECT_DEPENDS` also apply to the scan
   statement. The test driver re-checks this in build.ninja on every run.
4. MSVC with Ninja: `/translateInclude` is appended to `CMAKE_CXX_MODULE_MAP_FLAG` (`@<MODULE_MAP_FILE>`), which only
   CMake's scanned compile rule uses.

## Limitations

* This is a prototype. Kitware considers DIY header units unsupported; CMake issue #25293 tracks native support.
* GCC/Clang:
  * single-config Ninja only;
  * header-unit sets cannot be installed or exported;
  * BMIs cannot be moved to another location.
* GCC:
  * one header unit per header per build tree;
  * no spaces in source, header or build paths;
  * on Windows (MinGW-w64), t02_thirdparty fails to link: fmt's function-local static arrays in inline functions,
    reached through the header unit and through `#include` in two TUs, are reported as multiple definitions. This
    predates the header lookup without `try_compile` (same failure with the earlier code).
* A consumer whose include path finds, for a header of its sets, another file that has no header unit gets a
  configure warning: an import of that header fails to compile (a `#include` of it stays textual).
* The lookup takes a target's own `target_include_directories(SYSTEM ...)` directory for an `-I` one (CMake does not
  expose the difference at configure time); it matters only if a later `-I` directory has a header of the same name.
* The consumer/set compatibility check reads target and directory properties. Flags that only exist at generate time
  are caught by the compiler when it loads the BMI instead. Examples: a linked library's
  `INTERFACE_COMPILE_OPTIONS -std=...`, or generator expressions.
* Clang itself marks header units experimental; the module silences `-Wexperimental-header-units`.
* MSVC:
  * MSBuild does not translate `#include` into imports in this setup (with Ninja the module does);
  * fmt 10.1.1 header-only does not link through a header unit with MSVC 19.44, built by MSBuild or by this module
    (`format_facet<std::locale>::do_put` unresolved; see Tests);
  * with Ninja, Ninja leaves headers under "Program Files" or "Microsoft Visual Studio" out of its dependency
    records (for every MSVC compile, not only header units): an update of Visual Studio or the Windows SDK does not
    rebuild the header units of the C++ library. Delete the build directory after one.

## Repository layout

```
cmake/HeaderUnits.cmake          entry point: include(HeaderUnits)
cmake/HeaderUnits/Core.cmake     add_header_units, target_import_header_units, finalization
cmake/HeaderUnits/Common.cmake   header lookup, import scanning, usage requirements, compatibility check
cmake/HeaderUnits/hu-mapper.cpp  GCC: the mapper of a header unit's own compile (built at configure time)
cmake/HeaderUnits/Auto.cmake     target_auto_header_units
cmake/HeaderUnits/GCC.cmake      GCC strategy
cmake/HeaderUnits/Clang.cmake    Clang strategy
cmake/HeaderUnits/MSVC.cmake     MSVC with a Visual Studio generator: pass-through
cmake/HeaderUnits/MSVCNinja.cmake  MSVC strategy with Ninja
tests/t01..t21/                  test projects; tests/run_suite.cmake is the driver
tests/attack/                    adversarial scenarios (run_attack.cmake, RESULTS.md)
tools/update_release_branch.cmake  makes the next commit of the `release` branch from a commit of main (see Release branch)
tools/release-README.md          the `release` branch's README
run-linux.sh, run-win.bat        run the suite (GCC + Clang on Linux; clang++ + MSVC STL on Windows)
run-msvc.bat                     build and run the test projects with MSVC and a Visual Studio generator
run-msvc-ninja.bat               run the suite with MSVC and Ninja
docker/                          the Linux toolchain image used for development (GCC 16, Clang 22, fmt, json, Boost)
docs/REPORT.md                   research report (in Chinese): CMake's position, compiler behaviour, prior art
```

## Release branch

`release` holds only `cmake/`, `LICENSE` and a short README (`tools/release-README.md`), so FetchContent downloads
just the module. Each of its commits names the main commit its files come from. To publish the module of a main commit:

```sh
cmake -P tools/update_release_branch.cmake            # from HEAD; or -DFROM=<commit> before -P
git push origin release
```

## Tests

Each test is a standalone CMake project with a one-line README:

| test | what it covers |
|---|---|
| t01_stl | `import <vector>/<string>/<iostream>` in a plain executable |
| t02_thirdparty | fmt + nlohmann_json (+ Boost on Linux) + STL header units in one TU; overlapping sets; GCC build-order independence |
| t03_named_modules | named modules with `export import <vector>`; cross-target importers, including CMake's synthesized BMI targets |
| t04_shared_set | two targets share a set; incompatible consumers (C++23, extensions off, `-fno-exceptions`, a consumer-only `_GLIBCXX_DEBUG` / `_ITERATOR_DEBUG_LEVEL`, duplicate header) are rejected at configure time |
| t05_rebuild | no-op build; touching or same-size edits of headers rebuild BMIs before consumers |
| t06_mixed | header units and textual `#include` of overlapping headers in one TU, in every order; a TU excluded via `SOURCES` |
| t07_own_headers | the project's own headers (in-tree library, local header) as header units; `#include` of them is translated |
| t08_auto | `target_auto_header_units`: sets generated from imports; a second target reuses them |
| t09_header_import_error | a header containing `import` is rejected ("not supported yet") |
| t10_header_imports | `HU_ALLOW_HEADER_IMPORTS`: headers importing header units (auto and manual, within and across sets), rebuild propagation |
| t11_transitive | the header lookup follows in-tree link interfaces recursively (ALIAS, imported, cross-directory, `LINK_ONLY`) |
| t12_build_tree | headers inside the build tree: a FetchContent dependency and a `configure_file` header |
| t13_same_name | two targets whose `<config.h>` are different files get one header unit each; `<vector>` (same file) is shared |
| t14_textual_pragma | `// HeaderUnits pragma: textual-includes`: an stb-style `IMPLEMENTATION` include stays textual, the source's own imports still use header units |
| t15_scan_sources | `target_header_units_scan_sources`: only the listed sources are scanned and get header units (two calls for one target); an unlisted source keeps a macro-configured `#include` textual; a non-source is rejected |
| t16_deferred | both commands written before the target's settings in the same file: link library, include directories, directory definition and compile options all reach the header units; a later change from the parent directory is reported |
| t17_lookup | the header lookup follows the compiler's search list: the first `-I` directory wins over a later one and over `-isystem` (an imported target's); an include directory spelled with `..`; `-isystem` in `CMAKE_CXX_FLAGS` and, in a Release build, in `CMAKE_CXX_FLAGS_RELEASE` (in Debug that import is in an inactive `#ifdef` and its header is not found: skipped); `CMAKE_INCLUDE_CURRENT_DIR`; the C++ library's directory given again with `-I`; (not on Windows) a directory reached through a symbolic link; with GCC 16, C++26 and `-freflection`; an IDE-style probe of the header-unit flags (`-E`, no `-M`); a source at a long path |
| t18_spelling | an explicit set whose consumer, in a later directory, spells the include directory differently (`app/../inc`); both list a directory that does not exist first |
| t19_scale | 5 and 40 targets, each with its own include directory and header: the number of compiler runs for the lookup is the same |
| t20_wrong_file | a consumer whose include path finds another `a.h` (without a header unit) than its set's: configure warns, naming both files; the build then fails on `dirB/a.h` |
| t21_self_include | a header that includes itself through another one (as fmt's `core.h` includes `"format.h"`): builds, rebuilds after a change to a header it includes, and is a no-op after each build; with GCC also with `HU_GCC_WRAPPERS` and cross-compiling (an explicit `CMAKE_SYSTEM_NAME`: `hu-mapper` built by the host compiler) |

For each test, `tests/run_suite.cmake` runs:

* a fresh configure and build, then ctest;
* a no-op check: a second build has nothing to do;
* a build.ninja check: the scan and compile of every consumer depend on its BMIs, with identical flags;
* depfile evidence: every imported header is read from its BMI, never parsed textually;
* a negative check: without the BMI, the consumer's compile fails;
* the test's own steps.

How to run:

* Linux: `sh run-linux.sh` runs GCC and Clang in parallel. Options: `CMAKE_EXE`, `CLANG_CXX`, `CLANG_FLAGS`,
  `TESTS="t01;t05"`. Build on a native Linux file system; under WSL, not on `/mnt/c`.
* Windows, clang++ + MSVC STL: `run-win.bat`. It needs clang++, ninja and cmake on PATH, and finds Visual Studio via
  vswhere. It also needs the fmt 10.1.1 and nlohmann_json 3.11.3 sources:

  ```
  git clone --depth 1 --branch 10.1.1 https://github.com/fmtlib/fmt.git ext-src/fmt
  git clone --depth 1 --branch v3.11.3 https://github.com/nlohmann/json.git ext-src/nlohmann_json
  ```
* Windows, MinGW-w64 GCC: no runner script yet. With the MinGW `bin` directory (which also serves the test
  executables' runtime DLLs), ninja and cmake on PATH:

  ```
  cmake -DTC=mingw -DMINGW_CXX=C:/mingw64/bin/g++.exe -DCMAKE_EXE=<cmake under test> -DTAG=local -P tests/run_suite.cmake
  ```

  `MINGW_CXX` defaults to `g++`; the results land in `_build/mingw-local/results.txt`.
* Windows, clang++: `vcvars64.bat` puts Visual Studio's own, older Clang (19.1.5 with Visual Studio 2022 17.14) first on
  PATH, which cannot build header units of the C++ library with Windows SDK 10.0.26100; `set CLANG_CXX=<path to
  clang++.exe>` selects another.
* Windows, MSVC: `run-msvc.bat` configures, builds and runs ctest with a Visual Studio generator; t04 and t09 are
  skipped. `run-msvc-ninja.bat` runs the suite with MSVC and Ninja (`TC=msvc`). There, Ninja keeps no C++ library
  header in its dependency records, so the checks that a library header was read textually or from its BMI see nothing
  for those headers; the IDE probe and t04's extensions variant do not apply.
* Adversarial scenarios: `tests/attack/run-attack-linux.sh` and `tests/attack/run-attack-win.bat`; results are in
  `tests/attack/RESULTS.md`.

## Results

**2026-11-19, Windows 11, CMake 4.5.0** (fresh build directories; Visual Studio 2022 17.14 with MSVC 19.44, Windows SDK
10.0.26100): MSVC with Ninja (`TC=msvc`): 18 PASS, and t02_thirdparty, t08_auto and t11_transitive fail the known way
(XFAIL; fmt does not link through a header unit, as with MSBuild). clang++ 22.1.8 + MSVC STL (`TC=win`): 21/21 PASS.
MinGW-w64 GCC 16.1 (`TC=mingw`): 20 PASS, t02_thirdparty XFAIL; with CMake 4.3.1 t03_named_modules passes as well (its
#28166 probe needs CMake 4.4). The Linux toolchains were not rerun for these changes. Configure time of a project with
40 targets, 1000 sources and 70 header units (MinGW GCC): 42.5 s before the per-search-list maps, 7.6 s after.

**2026-11-19, after the lookup rework and GCC's hu-mapper** (fresh build directories): t01-t21 **63/63 PASS** on GCC
16.2 and Clang 22 + libstdc++ (Linux, CMake 4.4.5) and clang++ + MSVC STL (Windows, CMake 4.5.0). MinGW-w64 GCC 16.1
(`TC=mingw`, CMake 4.5.0): 20 PASS, and t02_thirdparty fails the known way (XFAIL; link: multiple definitions in fmt).
t08_auto (fmt's self-include) and t12_build_tree (a header in the build tree), which failed there before, pass. With
GCC, t21_self_include also covers the wrapper fallback (`HU_GCC_WRAPPERS`) and a cross build (an explicit
`CMAKE_SYSTEM_NAME`: `hu-mapper` built by the host compiler). t19_scale: 5 and 40 targets both take 2 compiler runs
for the header lookup at configure time (one lookup run plus the self-check).

Earlier the same day, the header lookup without `try_compile`: configure time of t02_thirdparty (3 sets) on Windows
with MinGW went from 11.7 s to 1.9 s, of which 1.4 s is CMake's own compiler detection.

The table is the run before that change (2026-11-17, fresh build directories).

GCC/Clang suite then: **96/96 PASS**, i.e. t01-t16 x {GCC 16, Clang 22 + libstdc++, clang++ + MSVC STL} x CMake {4.5.0, 4.4.5}.
The last column is the MSVC pass-through (`run-msvc.bat`: MSVC 19.44, Visual Studio 17 2022, CMake 4.5.0; configure,
build and ctest only).

| test | gcc 4.5.0 | gcc 4.4.5 | clang 4.5.0 | clang 4.4.5 | win clang++ 4.5.0 | win clang++ 4.4.5 | MSVC (MSBuild) |
|---|---|---|---|---|---|---|---|
| t01_stl | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t02_thirdparty | PASS | PASS | PASS | PASS | PASS (no Boost) | PASS (no Boost) | FAIL (link, fmt) |
| t03_named_modules | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t04_shared_set | PASS | PASS | PASS | PASS | PASS | PASS | skipped |
| t05_rebuild | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t06_mixed | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t07_own_headers | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t08_auto | PASS | PASS | PASS | PASS | PASS | PASS | FAIL (link, fmt) |
| t09_header_import_error | PASS | PASS | PASS | PASS | PASS | PASS | skipped |
| t10_header_imports | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t11_transitive | PASS | PASS | PASS | PASS | PASS | PASS | FAIL (link, fmt) |
| t12_build_tree | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t13_same_name | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t14_textual_pragma | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t15_scan_sources | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| t16_deferred | PASS | PASS | PASS | PASS | PASS | PASS | PASS |

The three MSVC failures share one cause outside this module: fmt 10.1.1 in header-only mode, imported through a header
unit that MSBuild builds, does not link with MSVC 19.44 (unresolved `fmt::format_facet<std::locale>::do_put`). A
project without HeaderUnits.cmake shows the same: `#include <fmt/format.h>` links, `import <fmt/format.h>;` does not.

Adversarial scenarios (`tests/attack/RESULTS.md`): after the fixes every scenario behaves as expected on all three
toolchains. The remaining failures are the documented limitations: consumer-only `_GLIBCXX_DEBUG` (a04), and on GCC
a symlinked include directory (a08).


## Background

CMake's documentation says "Header units are not supported" for all generators (through 4.5); native support is
planned in issue #25293. GCC's and Clang's dependency scanners cannot discover header units on their own, because a
header unit's macros make the scan itself depend on the BMIs. This is why the module needs the headers up front:
either declared, or discovered from literal import declarations at configure time. `docs/REPORT.md` (in Chinese)
has the full investigation: CMake's behaviour, per-compiler experiments, prior art (build2, xmake, Buck2, MSBuild) and
the design choices.

## License

MIT, see `LICENSE`.
