+++
title = "MSVC with Ninja: how the module builds header units for cl, and what cl/CMake/Ninja forced"
kind = "design"
keys = [ "headerunit", "ifc", "msvc", "ninja", "pitfall", "translateinclude" ]
updated = "2026-11-19 03:54:55"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "string(APPEND CMAKE_CXX_MODULE_MAP_FLAG \" /translateInclude\")"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "COMPILE_OPTIONS \"/exportHeader;/ifcOnly;/ifcOutput;${rcmi}\")"

[[links]]
path = "cmake/HeaderUnits/MSVCNinja.cmake"
snippet = "set_property(TARGET ${it} APPEND PROPERTY INTERFACE_COMPILE_OPTIONS \"@${irsp}\")"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "    set(cmd \"${CMAKE_CXX_COMPILER}\" /nologo ${args} /Zs /showIncludes \"${src}\")"
+++
cl's scan + CMake's collate accept `import <vector>;` (CMake 4.5.0); only the IFC is missing, so the module builds it as GCC's CMI. Facts (MSVC 19.44, 2026-11-19):
- IFC = the set's object: /exportHeader /ifcOnly /ifcOutput <obj>. Consumers: /headerUnit "<path>=<ifc>" lines in a per-source rsp.
- /translateInclude not per source: per-source options reach CMake's scan, and cl /scanDependencies with it recurses forever into a self-including header (fmt core.h, t21: C1014). Appended to CMAKE_CXX_MODULE_MAP_FLAG (compile rule only); without a mapping it changes nothing.
- Source COMPILE_OPTIONS take no SHELL:, and a repeated /headerUnit would be de-duplicated: response files.
- An importer of a named module that export-imports a header unit needs its /headerUnit too (C7612; not GCC/Clang): iface rsp in the module target's INTERFACE_COMPILE_OPTIONS and its own COMPILE_OPTIONS (else CMake synthesizes a BMI per importer). The importer's scan does not need the IFC.
- Search list: no -E -v; from INCLUDES (/I, /external:I), CMAKE_CXX_FLAGS(+config), options, then INCLUDE. /external:I needs /external:W0. Self-check: /Zs /showIncludes (stdout; the prefix ends with a blank).
- Ninja's msvc deps drop headers under Program Files / Microsoft Visual Studio (plain projects too): test checks on library headers skip TC=msvc.
- Missing IFC: C7612 names the header, not the file. fmt 10.1.1 header-only does not link (do_put), as with MSBuild: t02/t08/t11 XFAIL.