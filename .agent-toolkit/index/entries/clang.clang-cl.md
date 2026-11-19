+++
title = "clang-cl (Clang's MSVC-style driver): the Clang strategy with /clang: options; what clang-cl and CMake forced"
kind = "design"
keys = [ "clang", "clang-cl", "lookup", "pitfall", "windows" ]
updated = "2026-11-19 06:09:40"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/Clang.cmake"
snippet = "  set_property(GLOBAL PROPERTY _HU_CLANG_FWD \"/clang:\")"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "    set(args -I \"${mI}\" /external:I \"${mB}\" -imsvc \"${mS}\")"

[[links]]
path = "cmake/HeaderUnits/Clang.cmake"
snippet = "list(APPEND copts \"/clang:-o${od}/$<TARGET_PROPERTY:NAME>.dir/${cfg}hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}\")"
+++
clang-cl (CMAKE_CXX_COMPILER_FRONTEND_VARIANT MSVC) is _HU_TC Clang: the same module maps, PCMs and response files as clang++. Facts (LLVM 22.1.8, CMake 4.5.0):
- Taken bare by clang-cl: -fmodule-header=system, -xc++-system-header, -fmodule-map-file=, -fmodule-file=<name>=<pcm>, -W options. Only with /clang: (_HU_CLANG_FWD): -fmodule-name (or -Xclang), -fmodule-file-deps (bare: "unknown argument ignored", and the PCM drops out of the depfile), -o.
- PCM path: clang-cl ignores /Fo for a header unit and its own -o is cl's /o; without /clang:-o it writes <name>.pcm into Ninja's working directory. CMake's own CMAKE_CXX_COMPILE_BMI for clang-cl uses -clang:-o too. Source options are per directory (shared by every set of a directory with that header), so the path is spelled with $<TARGET_PROPERTY:NAME>, which is evaluated per compiling target (checked with two sets in one directory).
- Pitfall: /clang:-o wins over any -o, so an IDE-style -E rerun of a header unit's flags writes over the PCM. t17's IDE probe is skipped for TC=clangcl; README Limitations.
- CMake 4.5 for clang-cl: gcc-style depfiles (-clang:-MD), so ninja -t deps lists PCMs and library headers and the TC=msvc exemptions are not needed; -std:c++20 for both CXX_EXTENSIONS values (the compat check then ignores extensions; t04's ext variant is skipped); CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES is empty; CMAKE_CXX_EXTENSIONS_DEFAULT is ON.
- Lookup: -x c++ -E -v works as for clang++. SYSTEM directories come as -imsvc<dir> (CMAKE_INCLUDE_SYSTEM_FLAG_CXX) and are searched after clang's own lib/clang/22/include; /external:I (clang's -isystem) directories come right after the -I ones, so the marker mB (@B) shows _hu_search_list where the system directories start. The self-check needs /clang:-H (a bare -H is ignored).
- -fno-exceptions and -fno-rtti are ignored by clang-cl (warning); -EHsc, -GR- and /clang:-f... are accepted, so the compat regex takes [-/]EH, [-/]GR-? and /clang:-f(no-)?(exceptions|rtti).
