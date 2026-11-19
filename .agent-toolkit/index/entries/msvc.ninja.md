+++
title = "MSVC with Ninja: how the module builds header units for cl, and what cl/CMake/Ninja forced"
kind = "design"
keys = [ "headerunit", "ifc", "msvc", "ninja", "pitfall", "translateinclude" ]
updated = "2026-11-19 05:30:00"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "COMPILE_OPTIONS \"/exportHeader;/ifcOnly;/ifcOutput;${rcmi}\")"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "    set(cmd \"${CMAKE_CXX_COMPILER}\" /nologo ${args} /Zs /showIncludes \"${src}\")"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "string(APPEND CMAKE_CXX_SCANDEP_SOURCE \" /translateInclude-\")"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "set_property(GLOBAL PROPERTY _HU_MSVC_TOOLCHAIN_DEPS \"${_HU_DIR}/msvc-toolchain.txt\" \"${CMAKE_CXX_COMPILER}\")"
+++
cl's scan + CMake's collate accept `import <vector>;` (CMake 4.5.0); only the IFC is missing, so the module builds it as GCC's CMI. Facts (MSVC 19.44, 2026-11-19):
- IFC = the set's object: /exportHeader /ifcOnly /ifcOutput <obj>. Consumers: /headerUnit "<path>=<ifc>" lines in a per-source rsp.
- /translateInclude per consumer (rsp), and "/translateInclude-" appended to CMAKE_CXX_SCANDEP_SOURCE: per-source options reach CMake's scan, and cl /scanDependencies with /translateInclude recurses forever into a self-including header (fmt core.h, t21: C1014). Not in the compile rule for all sources: with the iface mappings it translated #includes of non-consumers (t15's c.cpp).
- Source COMPILE_OPTIONS take no SHELL:, and a repeated /headerUnit would be de-duplicated: response files.
- An importer of a named module that export-imports a header unit needs its /headerUnit too (C7612; not GCC/Clang): iface rsp in the module target's INTERFACE_COMPILE_OPTIONS and its own COMPILE_OPTIONS (else CMake synthesizes a BMI per importer). The importer's scan does not need the IFC.
- Search list: no -E -v; from INCLUDES (/I, /external:I), CMAKE_CXX_FLAGS(+config), options, then INCLUDE. /external:I needs /external:W0. Self-check: /Zs /showIncludes (stdout; the prefix ends with a blank).
- Ninja's msvc deps drop headers under Program Files / Microsoft Visual Studio (plain projects too; `ninja -t deps`: #deps 0 for IFCs and consumers): test checks on library headers skip TC=msvc. So every IFC also depends on cl.exe (VS servicing replaces it in place: dir 14.44.35207 holds cl 19.44.35217; CMake keeps CMAKE_CXX_COMPILER_VERSION from the first configure) and on header_units/msvc-toolchain.txt (compiler, version, $ENV{INCLUDE}; file(CONFIGURE) at each CMake run). t01 (TC=msvc) checks it: a CMake run without changes compiles nothing (CMake's collate steps rerun once, it rewrites CXXDependInfo.json at each generate), INCLUDE plus an empty directory rebuilds the IFCs, then main.cpp. Not covered: an SDK update in place (same 10.0.x.0 directory), a build from another environment without a CMake run.
- Missing IFC: C7612 names the header, not the file. fmt 10.1.1 header-only does not link (do_put), as with MSBuild: t02/t08/t11 XFAIL.