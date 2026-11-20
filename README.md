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
| Clang 22 + libc++ 22 (Linux) | Ninja | this module |
| Clang 22 (`clang++`, GNU-style driver) + MSVC STL (Windows) | Ninja | this module |
| Clang 22 (`clang-cl`, MSVC-style driver) + MSVC STL (Windows) | Ninja | this module |
| MSVC 19.44 (Windows) | Visual Studio 17 2022 | MSBuild (the commands do nothing) |
| MinGW-w64 GCC 16.1 + libstdc++ (Windows) | Ninja | this module |
| MSVC 19.44 (Windows) | Ninja | this module |

MinGW-w64 GCC is tested with CMake 4.5.0 and 4.3.1, MSVC with Ninja and clang-cl with CMake 4.5.0 (see Results).

GCC and Clang also work with the **Ninja Multi-Config** generator (a BMI per configuration). Not supported: MSVC with
Ninja Multi-Config (rejected at configure time: Ninja learns an MSVC compile's inputs from `/showIncludes`, which lists
no IFCs, so consumers would not rebuild when a header unit changes).

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
     GIT_TAG        release               # the latest; or a version tag, e.g. v0.1.0 (for a commit hash, drop GIT_SHALLOW)
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
   cmake -S . -B build -G Ninja -DCMAKE_CXX_COMPILER=g++     # or clang++, or clang-cl (from a developer prompt)
   cmake --build build
   # GCC / Clang, several configurations in one build directory:
   cmake -S . -B build -G "Ninja Multi-Config" -DCMAKE_CXX_COMPILER=g++
   cmake --build build --config Release
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

Requirements: GCC/Clang need CMake >= 4.2, the **Ninja** or **Ninja Multi-Config** generator and C++20 or later; clang-cl runs
from a developer prompt. MSVC needs CMake >= 3.28 and a Visual Studio generator, or CMake >= 4.2, Ninja and MSVC 19.40
(Visual Studio 2022 17.10) or later, run from a developer prompt.

## Commands

A target's C++ sources are the files CMake compiles as C++ for it: its `SOURCES` and `CXX_MODULES` file sets, by the
source's `LANGUAGE` property or else its extension (`CMAKE_CXX_SOURCE_FILE_EXTENSIONS`), except `HEADER_FILE_ONLY`
ones. Sources given with generator expressions (`$<TARGET_OBJECTS:...>`, a source of some configurations) are only
known when CMake generates the build system: the commands do not see them (not scanned, no header units). A relative
path names the file where CMake finds it: in the source directory, else in the build directory (a generated source).

### target_auto_header_units

```
target_auto_header_units(<target> [LINK_LIBRARIES <tgt>...] [INCLUDE_DIRECTORIES <dir>...] [COMPILE_DEFINITIONS <def>...]
                         [COMPILE_OPTIONS <opt>...] [CXX_STANDARD <n>] [CXX_EXTENSIONS <bool>]
                         [EXCLUDE <name>...] [NO_RECONFIGURE])
```

* Scans the target's C++ sources for `import <x>;` and `import "x";` (also with
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
* The scan and the header lookup run in `hu-mapper` (see "How it works"), all requests of a directory in one run, with
  a cache of each source's import lines by modification time and size (`CMakeFiles/header_units/scan-cache.txt`), so a
  reconfigure reads only the sources that changed. `-DHU_NATIVE_SCAN=OFF`, or a compiler that cannot build
  `hu-mapper`, scans with CMake instead: the same result, slower.
* Only literal import declarations are recognized:
  * imports produced by macros are not;
  * imports inside `#if` are considered whatever the condition. A header that cannot be found with the target's include
    paths is skipped silently (e.g. a platform header in an inactive branch; shown with `--log-level=VERBOSE`). A header
    that exists but does not compile as a header unit in this configuration still fails the build.

### target_header_units_scan_sources

```
target_header_units_scan_sources(<target> <src>... [same options as target_auto_header_units])
```

The same as `target_auto_header_units`, but only for the listed sources:

* only they are scanned for imports, and only they receive header units. The target's other sources are left alone:
  their `#include`s stay textual, and an `import` in them does not compile;
* a relative path is looked up in the current source directory, else in the current build directory. A file that is
  not a C++ source of the target, or that does not exist at configure time (generated at build time), is a
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
  directories where CMake puts a target's `-I` and `-isystem` directories (with clang-cl `-imsvc`, which it searches
  after its own include directory); a target's list is that list with its own directories in their places. So the
  number of compiler runs follows the number of distinct option sets (usually one to three), not the number of
  targets; configure prints it. Nothing is compiled at configure time. A configure-time self-check (one more run, with
  the options of the first lookup) stops the configure if the compiler finds or names headers otherwise than this
  predicts; if its probe cannot run, it only warns. A header found only through a directory given as an unevaluable
  generator expression is not found: pass that directory with `INCLUDE_DIRECTORIES`. With Ninja Multi-Config the
  header is looked up with each configuration's flags (`CMAKE_CXX_FLAGS_<CONFIG>`; configurations whose flags differ
  only in warnings, `-D`/`-U`, `-O` and `-g`, as CMake's defaults do, share the run): a header unit is compiled from
  one file for all configurations, so a header that another configuration finds as another file (or not at all), e.g.
  through an include directory in `CMAKE_CXX_FLAGS_RELEASE`, stops the configure with both files named.
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

Gives the set's header units to all C++ sources of the target, or only to the listed ones (a relative path as for
`target_header_units_scan_sources`).

* The consumer's language settings must match the set's: C++ standard, extensions (not with MSVC and clang-cl, where
  they change nothing), exception and RTTI options,
  `CMAKE_CXX_FLAGS`, and definitions that change the C++ library's ABI (`_GLIBCXX_DEBUG`, `_GLIBCXX_USE_CXX11_ABI`,
  `_LIBCPP_ABI_*`; with the MSVC STL `_ITERATOR_DEBUG_LEVEL`, `_HAS_ITERATOR_DEBUGGING`, `_SECURE_SCL`,
  `_HAS_EXCEPTIONS` and `MSVC_RUNTIME_LIBRARY`) from the target, its directory and its link interface. This is checked
  at configure time.
* A source used by several targets, in any directories, must get the same sets. They may spell their include
  directories differently: with GCC the source's map holds the spelling of every target. With Clang, clang-cl and MSVC
  a header may be in several sets, each building its own BMI; a source must not get two of them (configure error, t04).
  With GCC a header has one header unit per build tree (Limitations).

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
* `hu-mapper` (`cmake/HeaderUnits/hu-mapper.cpp`, C++17, no dependencies) is built once per build tree at configure
  time with the project's compiler (cross-compiling: a host compiler, see GCC below), rebuilt only when its source
  changes. It scans sources for import declarations and the `textual-includes` marker, resolves the
  imported names against the search list, and keeps a scan cache (a source it cannot read, e.g. locked by an editor or
  a virus scanner on Windows, is reported and never cached; that run falls back to CMake's scan); with GCC it is also
  the module mapper. On Windows it reads its arguments from the wide command line as UTF-8 and opens files with
  `_wfopen`, so non-ASCII paths match `hu-index.txt` and the maps; it is linked by a relative path because MinGW's `ld`
  uses the ANSI code page. It computes
  what the CMake functions `_hu_scan_imports`, `_hu_import_name` and `_hu_find_header` compute, which remain the
  fallback. On a project of 1000 sources in 20 targets with `target_auto_header_units`, a reconfigure took about 2 s
  with `hu-mapper`'s scan and 3-3.5 s with CMake's (MinGW GCC, clang++ and MSVC; the same build files either way).
* BMI paths are spelled relative to the build directory, so compiler depfiles name the same Ninja nodes and an edit
  rebuilds everything that depends on it in one `ninja` run.
* Ninja Multi-Config: each configuration has its own BMIs (`CMakeFiles/<set>.dir/<config>/hu/...`), and the files
  that name them (Clang's response files, GCC's mapper files and `hu-index.txt`) are written per configuration with
  `file(GENERATE)` and `$<CONFIG>`; GCC's compile rule names the index with Ninja's `$CONFIG`. `OBJECT_DEPENDS` takes
  no per-configuration paths, so consumers get none: the `<set>_ready` targets order their scan and compile after the
  BMIs, and the compiler's depfile, which names each BMI it read, rebuilds them when one changes.

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
* Each consumer source gets a map listing its header units, under every spelling the targets compiling it use (GCC
  names a header unit by the spelling of the include directory it found it in, e.g. `app/../inc`). GCC also translates
  `#include`s of listed headers into imports. `hu-index.txt` (one line per source and target that imports header units
  for it, naming the target's object directory and the map; read by the compile's mapper) is removed at
  the start of every configure and rewritten at its end, so it describes exactly the current configure: with no
  consumer left it is empty or missing, and every `#include` stays textual. Another target that compiles the same source
  without importing header units finds no line for its object directory: its `#include`s stay textual and its build
  needs no header unit. Sources with the same content share one map (`gcc-m/<hash>.map`).
* CMake's internal `CMAKE_CXX_MODULE_MAP_FLAG` is overridden so the compile serves CMake's named-module map and the
  header-unit map together: GCC starts `hu-mapper -c <module map> <index>`, which reads both and finds the source's
  map in `hu-index.txt`; the dependency scan uses `hu-mapper -s <map>`. GCC splits that option at blanks, with no
  quoting, so `hu-mapper` and its files are named relative to the top build directory (the working directory of every
  Ninja command), and the source is not on it: `hu-mapper` reads it from the scan's depfile next to the module map
  (`<object>.ddi.d`, its first prerequisite). No shell or `cmd.exe` runs in between, so paths may hold `, ; =`, blanks
  and the like; `hu-mapper` reads its map entries quoted as in GCC's protocol. Only the object directory of a target
  (its binary directory below the build tree) may not hold blanks: it is part of the module map's path.
* Headers inside the build tree (FetchContent dependencies, `configure_file` headers) need nothing special: `hu-mapper`
  answers the export whatever name GCC uses (CMake passes such a source relative to the build directory).
* Without `hu-mapper` (cross-compiling without a host compiler, or `HU_GCC_WRAPPERS`), consumers use GCC's
  `g++-mapper-server` through a script: `gcc-mapper.sh`, or on Windows `gcc-mapper.cmd` run through `cmd /c` (there a
  build directory or source path with `& | < > ^ % , ; =` is rejected at configure time). The script finds the source's
  map in `hu-index.txt`, so the maps are the same shared ones. GCC's own mapper-file reader has no quoting, so a header
  path, source path or build directory with blanks is rejected at configure time. Mapper files get short hashed names, because paths past 260
  characters do not open, and `\n` line ends, because GCC's mapper-file reader takes a `\r` as part of a word.

**Clang**, `clang++` and `clang-cl` (`cmake/HeaderUnits/Clang.cmake`), uses lazy, named header units (the Buck2
scheme):

* A module map declares the real header as the only header of a module, and the BMI is built with `-fmodule-name`.
* Consumers get `-fmodule-map-file` and `-fmodule-file=<name>=<bmi>` in a response file, one per distinct content (sources
  with the same sets share it). Any `#include` or
  `import` that resolves to the header becomes an import, in any order, and a BMI is only read by sources that reach
  its header.
* The response file keeps command lines short: CMake runs the dependency scan on Windows through cmd.exe, which
  allows at most 8191 characters.
* `clang-cl` gets the same options; those it has no cl spelling for take the `/clang:` prefix: `-fmodule-name`,
  `-fmodule-file-deps`, and `-o`, which names the BMI. `clang-cl` writes a header unit's BMI neither to `/Fo` nor to
  its own `-o`, which is cl's `/o`; CMake's own rule for a named module's BMI uses `-clang:-o` the same way.

**MSVC with a Visual Studio generator** (`cmake/HeaderUnits/MSVC.cmake`):

* CMake marks C++20 sources for module scanning and MSBuild builds the header units of their imports itself.
* The commands check their arguments, keep scanning on and otherwise do nothing.

**MSVC with Ninja** (`cmake/HeaderUnits/MSVCNinja.cmake`):

* A header unit is identified by the header's resolved path. Its IFC is built with `/exportHeader /ifcOnly` and written
  as the set's object file (`/ifcOutput`), so it is a real Ninja output. Source properties are per directory, so a
  header in two sets of one directory shares its options: `/ifcOutput` names the set's directory as
  `$<TARGET_PROPERTY:NAME>`, and the second set reuses the first one's object name.
* Ninja leaves headers under "Program Files" or "Microsoft Visual Studio" out of its dependency records, so it sees no
  header of the C++ library or the Windows SDK. Each IFC therefore also depends on the compiler and on a file in the
  build directory that records the compiler, its version and the `INCLUDE` environment variable; a CMake run rewrites
  the file only when one of them changed. An update of the compiler, or a CMake run after a change of the Visual Studio
  toolset or the Windows SDK, rebuilds the header units and their consumers.
* Each consumer source gets `/headerUnit "<header>=<ifc>"` for its header units and `/translateInclude` in a
  response file (one per distinct content). CMake's dependency scan gets the per-source options too, and `cl /scanDependencies` with
  `/translateInclude` recurses without end into a header that includes itself through another one, so CMake's scan rule
  gets `/translateInclude-` at its end.
* The header lookup assembles the include search list from the target's `/I` and `/external:I` directories, those in
  `CMAKE_CXX_FLAGS` and the compile options, and the `INCLUDE` environment variable; `cl` cannot print it. The
  self-check verifies it with `/showIncludes`.
* An importer of a named module whose interface imports header units needs those header units too (`cl` looks them
  up when it reads the module's IFC): the module's target gets them in its `COMPILE_OPTIONS` and
  `INTERFACE_COMPILE_OPTIONS`, without `/translateInclude`, so the #includes of its other sources and of its importers
  stay textual.

**CMake internals relied upon** (unsupported; grep `CMAKE-INTERNAL` in `cmake/`):

1. GCC: the `CMAKE_CXX_MODULE_MAP_FLAG` override (without `hu-mapper`, with Ninja's `$in` injected into it). The module
   stops with an error if a CMake release changes the template. The override names CMake's module map as `$out.modmap`
   (observed: the object path plus `.modmap`; CMake spells `<MODULE_MAP_FILE>` with backslashes on Windows), and
   `hu-mapper` reads the source from the scan's depfile `<object>.ddi.d` (observed: its first prerequisite).
2. The object location `<set binary dir>/CMakeFiles/<set>.dir/<OBJECT_NAME><ext>`, i.e. the default
   `CMAKE_INTERMEDIATE_DIR_STRATEGY` (`SHORT` is rejected); `clang-cl` is told to write the BMI there. If CMake moved
   objects, Ninja would stop with "missing and no known rule": a loud failure, never a silent misbuild.
3. Observed Ninja-generator behaviour: per-source `COMPILE_OPTIONS` and `OBJECT_DEPENDS` also apply to the scan
   statement. The test driver re-checks this in build.ninja on every run.
4. MSVC with Ninja: `/translateInclude-` is appended to `CMAKE_CXX_SCANDEP_SOURCE`, the template of CMake's dependency-scan
   rule. The module stops with an error if that template is no longer cl's `-scanDependencies` rule.
5. Ninja Multi-Config: objects in `CMakeFiles/<target>.dir/<config>/`, and the Ninja variable `CONFIG` that CMake sets on
   each compile edge (GCC's compile rule names the configuration's `hu-index.txt` with it).

## Limitations

* This is a prototype. Kitware considers DIY header units unsupported; CMake issue #25293 tracks native support.
* GCC/Clang:
  * Ninja and Ninja Multi-Config only. With Ninja Multi-Config: GCC needs `hu-mapper` (no `HU_GCC_WRAPPERS`),
    `HU_ALLOW_HEADER_IMPORTS` is rejected, and a header must be the same file in every configuration (an include
    directory in one configuration's `CMAKE_CXX_FLAGS_<CONFIG>` that shadows it stops the configure);
  * header-unit sets cannot be installed or exported;
  * BMIs cannot be moved to another location.
* GCC:
  * one header unit per header per build tree;
  * with `hu-mapper` (the default), blanks work in source, header and build directory paths, but not in the binary
    directory of a target below the build tree (an `add_subdirectory` with a blank: rejected at configure time);
    without it (`HU_GCC_WRAPPERS`, or cross-compiling without a host compiler), blanks work in none of them;
  * on Windows (MinGW-w64), non-ASCII source and build directories work with `hu-mapper` (the default); without it
    (`HU_GCC_WRAPPERS` ON), a non-ASCII build directory or header path is rejected at configure time: GCC quotes such a
    path in its module-mapper requests, which its own mapper-file reader does not understand;
  * on Windows (MinGW-w64), t02_thirdparty fails to link: fmt's function-local static arrays in inline functions,
    reached through the header unit and through `#include` in two TUs, are reported as multiple definitions. This
    predates the header lookup without `try_compile` (same failure with the earlier code).
* A consumer whose include path finds, for a header of its sets, another file that has no header unit gets a
  configure warning: an import of that header fails to compile (a `#include` of it stays textual).
* The lookup takes a target's own `target_include_directories(SYSTEM ...)` directory for an `-I` one (CMake does not
  expose the difference at configure time); it matters only if a later `-I` directory has a header of the same name.
* The consumer/set compatibility check compares `CMAKE_CXX_FLAGS` and the configuration's `CMAKE_CXX_FLAGS_<CONFIG>` of the
  consumer's and the set's directories without warning, diagnostic and debug-information options (a directory that adds
  `-Wall`, `-g3` or `/W4` stays compatible), and the ABI-affecting definitions; under Ninja Multi-Config
  for every entry of `CMAKE_CONFIGURATION_TYPES`, including configurations that are never built (the error names the
  configuration). Definitions inside generator expressions are not compared.
* The consumer/set compatibility check reads target and directory properties. Flags that only exist at generate time
  are caught by the compiler when it loads the BMI instead. Examples: a linked library's
  `INTERFACE_COMPILE_OPTIONS -std=...`, or generator expressions.
* Clang itself marks header units experimental; the module silences `-Wexperimental-header-units`.
* Clang with libc++ from the Debian or apt.llvm.org packages and CMake 4.5: the configure of every C++20 project fails,
  with or without this module, unless `CMAKE_CXX_STDLIB_MODULES_JSON` names
  `/usr/lib/llvm-<version>/lib/libc++.modules.json` (see Tests, How to run).
* clang-cl: a header unit's compile names its BMI with `/clang:-o`, which takes precedence over any other `-o`. A tool
  that reruns that command with `-E` or `/E`, as an IDE may do to read the compiler's settings, writes its output over
  the BMI unless it removes that option. Delete the BMI afterwards, so the next build makes it again.
* MSVC:
  * MSBuild does not translate `#include` into imports in this setup (with Ninja the module does);
  * fmt 10.1.1 header-only does not link through a header unit with MSVC 19.44, built by MSBuild or by this module
    (`format_facet<std::locale>::do_put` unresolved; see Tests);
  * with Ninja, a build directory with a character outside the ANSI code page fails the configure's header-lookup
    self-check: cl prints `/showIncludes` in the ANSI code page, where it becomes `?` (characters in it, e.g. "é", work;
    the module writes its response files with a UTF-8 byte order mark, which cl then reads as UTF-8). In a non-ASCII
    directory every build recompiles the TUs whose headers are there, also without this module: Ninja records cl's
    `/showIncludes` in the ANSI code page while CMake writes build.ninja in UTF-8;
  * with Ninja, Ninja leaves headers under "Program Files" or "Microsoft Visual Studio" out of its dependency
    records (for every MSVC compile, not only header units). The header units depend on the compiler and on the
    `INCLUDE` environment variable instead (see How it works), so a changed `INCLUDE` takes effect at the next CMake
    run, not at a build from another environment, and sources that import no header unit are not rebuilt. An update
    that replaces headers of the Windows SDK in their version directory goes unnoticed; delete the build directory
    after one.

## Repository layout

```
cmake/HeaderUnits.cmake          entry point: include(HeaderUnits)
cmake/HeaderUnits/Core.cmake     add_header_units, target_import_header_units, finalization
cmake/HeaderUnits/Common.cmake   header lookup, import scanning, usage requirements, compatibility check
cmake/HeaderUnits/hu-mapper.cpp  the import scan at configure time; GCC: the module mapper (built at configure time)
cmake/HeaderUnits/Auto.cmake     target_auto_header_units
cmake/HeaderUnits/GCC.cmake      GCC strategy
cmake/HeaderUnits/Clang.cmake    Clang strategy
cmake/HeaderUnits/MSVC.cmake     MSVC with a Visual Studio generator: pass-through
cmake/HeaderUnits/MSVCNinja.cmake  MSVC strategy with Ninja
tests/t01..t28/                  test projects; tests/run_suite.cmake is the driver, tests/run_parallel.cmake runs its
                                 tests in parallel (CTest)
tools/update_release_branch.cmake  makes the next commit of the `release` branch from a commit of main (see Release branch)
tools/release-README.md          the `release` branch's README
run-linux.sh, run-win.bat        run the suite (Linux: GCC, Clang + libstdc++, Clang + libc++; Windows: clang++ + MSVC STL)
run-clangcl.bat                  run the suite with clang-cl + MSVC STL
run-msvc.bat                     build and run the test projects with MSVC and a Visual Studio generator
run-msvc-ninja.bat               run the suite with MSVC and Ninja
docker/                          the Linux toolchain image used for development (GCC 16, Clang 22 with libc++, fmt, json, Boost)
docs/REPORT.md                   research report (in Chinese): CMake's position, compiler behaviour, prior art
```

## Release branch

`release` holds only `cmake/`, `LICENSE` and a short README (`tools/release-README.md`), so FetchContent downloads
just the module. Each of its commits names the main commit its files come from. To publish the module of a main commit:

```sh
cmake -P tools/update_release_branch.cmake            # from HEAD; or -DFROM=<commit> before -P
git push origin release
git tag -a v<x.y.z> release -m "HeaderUnits.cmake v<x.y.z>" && git push origin v<x.y.z>   # a version
```

Versions are tags on `release` commits, so `GIT_TAG v<x.y.z>` fetches only the module too. v0.1.0 (2026-11-19) was
the first; v0.1.1 (2026-11-20) is the latest.

## Tests

Each test is a standalone CMake project with a one-line README:

| test | what it covers |
|---|---|
| t01_stl | `import <vector>/<string>/<iostream>` in a plain executable; on Windows also a `target_auto_header_units` project in directories named `*-é中` (MSVC: `*-é`), first configured with its source locked: the lock is reported and not cached, and `hu-mapper` serves GCC from non-ASCII paths; on every toolchain, source and build directories with blanks and a source in a subdirectory with one (GCC: both sources read `<vector>` from its BMI) |
| t02_thirdparty | fmt + nlohmann_json (+ Boost on Linux) + STL header units in one TU; overlapping sets; GCC build-order independence |
| t03_named_modules | named modules with `export import <vector>`; cross-target importers, including CMake's synthesized BMI targets |
| t04_shared_set | two targets share a set; incompatible consumers (C++23, extensions off, `-fno-exceptions`, a consumer-only `_GLIBCXX_DEBUG` / `_ITERATOR_DEBUG_LEVEL`, a consumer directory's own `CMAKE_CXX_FLAGS_DEBUG`, duplicate header) are rejected at configure time; the flags and ABI cases also under Ninja Multi-Config, with the configuration named in the message (Debug only for `_ITERATOR_DEBUG_LEVEL=0` with the MSVC STL); a consumer directory that adds only warning / debug-information flags is accepted and builds |
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
| t15_scan_sources | `target_header_units_scan_sources`: only the listed sources are scanned and get header units (two calls for one target); an unlisted source keeps a macro-configured `#include` textual; a non-source is rejected; sources that stop being consumers (one dropped from `SOURCES`; the last import made an `#include`; no header-unit command left) include the header textually again (depfile) and see its edits, and with GCC `hu-index.txt` no longer names them |
| t16_deferred | both commands written before the target's settings in the same file: link library, include directories, directory definition and compile options all reach the header units; a later change from the parent directory is reported |
| t17_lookup | the header lookup follows the compiler's search list: the first `-I` directory wins over a later one and over `-isystem` (an imported target's); an include directory spelled with `..`; `-isystem` in `CMAKE_CXX_FLAGS` and, in a Release build, in `CMAKE_CXX_FLAGS_RELEASE` (in Debug that import is in an inactive `#ifdef` and its header is not found: skipped); `CMAKE_INCLUDE_CURRENT_DIR`; the C++ library's directory given again with `-I`; (not on Windows) a directory reached through a symbolic link; with GCC 16, C++26 and `-freflection`; an IDE-style probe of the header-unit flags (`-E`, no `-M`); a source at a long path |
| t18_spelling | an explicit set whose consumer, in a later directory, spells the include directory differently (`app/../inc`); both list a directory that does not exist first |
| t19_scale | 5 and 40 targets, each with its own include directory and header: the number of compiler runs for the lookup is the same |
| t20_wrong_file | a consumer whose include path finds another `a.h` (without a header unit) than its set's: configure warns, naming both files; the build then fails on `dirB/a.h` |
| t21_self_include | a header that includes itself through another one (as fmt's `core.h` includes `"format.h"`): builds, rebuilds after a change to a header it includes, and is a no-op after each build; with GCC also with `HU_GCC_WRAPPERS` and cross-compiling (an explicit `CMAKE_SYSTEM_NAME`: `hu-mapper` built by the host compiler), and with its headers in a directory with a space (with `HU_GCC_WRAPPERS` a configure error) |
| t22_import_std | `import std;` (CMake's `CMAKE_CXX_MODULE_STD`) in the same TUs as a header unit whose header includes `<string>`: one TU imports both, another `#include`s the header next to `import std;`. Needs CMake 4.5 (SKIP before: `import std` is experimental there); with Clang in the Linux image the driver names GCC's `libstdc++.modules.json` |
| t23_multi_config | Ninja Multi-Config: Debug and Release build and run with their own header units (the header's value depends on `NDEBUG`), each a no-op after; a header edit rebuilds the BMI and its consumers in one `ninja` run; a deleted BMI is rebuilt; the consumer's depfile names its BMI; the lookup uses each configuration's flags: an include directory in `CMAKE_CXX_FLAGS_RELEASE` whose `cfgval.h` loses on order is accepted (Debug and RelWithDebInfo share a compiler run), one whose `<vector>` shadows the C++ library's stops the configure naming the configurations and both files; MSVC (and GCC with `HU_GCC_WRAPPERS`) is rejected at configure time with the reason |
| t24_two_sets | one header in two sets of the same directory, each set imported by its own target (`<vector>`, and `<t24/val.h>`, which the second set spells `<val.h>`): GCC rejects the second set at configure time (one header unit per header per build tree); the other toolchains build four distinct BMIs, each consumer's compile gets only its own set's BMIs, and a deleted BMI is rebuilt alone with its consumer |
| t25_shared_source | one source compiled by three targets that import the same set, each spelling the include directory differently (`a/../inc`; in one directory `b/../inc` and `b/../b/../inc`): every compile imports `<sh.h>` and translates `#include <sh2.h>` (GCC: checked in the depfiles) |
| t26_shared_targets | one source compiled by a target that imports a set and, in another directory, by one that does not: a clean build of only the second builds no header unit and keeps the `#include` textual (depfile), also after an edit of the header |
| t27_module_two_targets | one module interface source (importing `<vector>`) compiled by two targets of one directory, each imported by a program without header units of its own: both programs build and run (with MSVC each module target's importers need its header-unit mappings) |
| t28_cxx_sources | which sources are a target's C++ sources, by one rule for the scan and the header units: a module unit in the default `CXX_MODULES` file set, a build-directory source listed by a relative path (also named in `target_header_units_scan_sources` and `target_import_header_units` `SOURCES`) and a `.c` file with `LANGUAGE CXX` are scanned and get header units; a `HEADER_FILE_ONLY` source is not scanned; generator-expression sources (a configuration's source, `$<TARGET_OBJECTS:...>`) are skipped |

For each test, `tests/run_suite.cmake` runs:

* a fresh configure and build, then ctest;
* a no-op check: a second build has nothing to do;
* a build.ninja check: the scan and compile of every consumer depend on its BMIs, with identical flags;
* depfile evidence: every imported header is read from its BMI, never parsed textually;
* a negative check: without the BMI, the consumer's compile fails;
* the test's own steps.

How to run:

* Every runner script uses `tests/run_parallel.cmake`: each test is a CTest test that runs `run_suite.cmake` for that
  test alone, `ctest -j` runs them (`JOBS=<n>` tests at a time, default a quarter of the logical cores; `NINJA_JOBS=<n>`,
  also as an environment variable, limits each test's own ninja, which otherwise uses every core), and the
  results are collected into the same `results.txt`. `run_suite.cmake` alone runs the tests one after another.
* Linux: `sh run-linux.sh` runs GCC, Clang with libstdc++ and Clang with libc++ in parallel (`TC=gcc`, `clang` and
  `libcxx`). Options: `CMAKE_EXE`, `CLANG_CXX`, `CLANG_FLAGS` (Clang with libstdc++), `LIBCXX_FLAGS` and
  `LIBCXX_MODULES_JSON` (Clang with libc++), `TESTS="t01;t05"`. Build on a native Linux file system; under WSL, not on
  `/mnt/c`. With libc++:
  * the tests use fmt header-only, because the image's fmt library is compiled against libstdc++;
  * the driver sets `CMAKE_CXX_STDLIB_MODULES_JSON` to `LIBCXX_MODULES_JSON` (default
    `/usr/lib/llvm-22/lib/libc++.modules.json`). CMake 4.5 sets up `import std` for every C++20 target, from the
    modules file that Clang names; in the image, that file's relative source paths resolve only from
    `/usr/lib/llvm-22/lib`, so without the setting every configure fails.
* Windows, clang++ + MSVC STL: `run-win.bat`. It needs clang++, ninja and cmake on PATH, and finds Visual Studio via
  vswhere. It also needs the fmt 10.1.1 and nlohmann_json 3.11.3 sources:

  ```
  git clone --depth 1 --branch 10.1.1 https://github.com/fmtlib/fmt.git ext-src/fmt
  git clone --depth 1 --branch v3.11.3 https://github.com/nlohmann/json.git ext-src/nlohmann_json
  ```
* Windows, MinGW-w64 GCC: no runner script yet. With the MinGW `bin` directory (which also serves the test
  executables' runtime DLLs), ninja and cmake on PATH:

  ```
  cmake -DTC=mingw -DMINGW_CXX=C:/mingw64/bin/g++.exe -DCMAKE_EXE=<cmake under test> -DTAG=local -P tests/run_parallel.cmake
  ```

  `MINGW_CXX` defaults to `g++`; the results land in `_build/mingw-local/results.txt`.
* Windows, clang-cl + MSVC STL: `run-clangcl.bat` (`TC=clangcl`), with the same requirements as `run-win.bat`. The IDE
  probe of t17 does not apply (see Limitations), nor does t04's extensions variant (`-std:c++NN` either way).
* Windows, clang++ and clang-cl: `vcvars64.bat` puts Visual Studio's own, older Clang (19.1.5 with Visual Studio 2022
  17.14) first on PATH, which cannot build header units of the C++ library with Windows SDK 10.0.26100; `set
  CLANG_CXX=<path to clang++.exe or clang-cl.exe>` selects another.
* Windows, MSVC: `run-msvc.bat` configures, builds and runs ctest (the one next to `CMAKE_EXE`) with a Visual Studio
  generator; t04 and t09 are skipped, and t02, t08 and t11 are XFAIL (fmt's `do_put`, see Limitations).
  `run-msvc-ninja.bat` runs the suite with MSVC and Ninja (`TC=msvc`). There, Ninja keeps no C++ library
  header in its dependency records, so the checks that a library header was read textually or from its BMI see nothing
  for those headers; the IDE probe and t04's extensions variant do not apply. t01 also checks that a CMake run without
  changes compiles nothing and that one with another `INCLUDE` rebuilds the header units and their consumer.

## Results

The full matrix at `69a26f9` (2026-11-19; fresh build directories, `tests/run_parallel.cmake`; Linux in the image of
`docker/`; Windows 11 with Visual Studio 2022 17.14 and Windows SDK 10.0.26100), with t03, t08, t15 and t28 run again
after the last changes to the source rule:

| toolchain | CMake 4.5.0 | CMake 4.4.5 |
|---|---|---|
| Linux, GCC 16.2 | 28/28 | 27 + t22 SKIP |
| Linux, Clang 22 + libstdc++ 16 | 28/28 | 27 + t22 SKIP |
| Linux, Clang 22 + libc++ 22 | 28/28 | 27 + t22 SKIP |
| Windows, clang++ 22.1.8 + MSVC STL | 28/28 | |
| Windows, clang-cl 22.1.8 + MSVC STL | 28/28 | |
| Windows, MinGW-w64 GCC 16.1 | 27 + t02 XFAIL | |
| Windows, MSVC 19.44 with Ninja | 25 + t02, t08, t11 XFAIL | |
| Windows, MSVC 19.44 with MSBuild (`run-msvc.bat`: t01-t16 without t04, t09) | 11 + t02, t08, t11 XFAIL | |

* t22 (`import std`) needs CMake 4.5.
* MinGW t02: fmt's function-local static arrays are reported as multiple definitions (see Limitations).
* MSVC t02, t08, t11: fmt 10.1.1 header-only, imported through a header unit, does not link with MSVC 19.44 (unresolved
  `fmt::format_facet<std::locale>::do_put`), with MSBuild too; a project without HeaderUnits.cmake shows the same:
  `#include <fmt/format.h>` links, `import <fmt/format.h>;` does not.

## Background

CMake's documentation says "Header units are not supported" for all generators (through 4.5); native support is
planned in issue #25293. GCC's and Clang's dependency scanners cannot discover header units on their own, because a
header unit's macros make the scan itself depend on the BMIs. This is why the module needs the headers up front:
either declared, or discovered from literal import declarations at configure time. `docs/REPORT.md` (in Chinese)
has the full investigation: CMake's behaviour, per-compiler experiments, prior art (build2, xmake, Buck2, MSBuild) and
the design choices.

## License

MIT, see `LICENSE`.
