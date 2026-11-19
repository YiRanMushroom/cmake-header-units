# HeaderUnits/GCC.cmake -- the GCC strategy (included by HeaderUnits.cmake when the C++ compiler is GCC).
#
# * A header unit is identified by the resolved path of its header.  Its BMI (CMI) is built with -fmodule-only as
#   the set's object file, through hu-mapper (hu-mapper.cpp, built at configure time): it gives GCC the CMI to write and
#   keeps every #include in the header textual, also one of the header itself (CMIs independent of build order).
#   Cross-compiling (or HU_GCC_WRAPPERS ON), the header is compiled from a wrapper instead (_hu_gcc_wrapper).
# * A consumer source gets a per-source mapper (g++-mapper-server) that lists its header units; GCC then also
#   translates an #include of a listed header into an import.
# * CMake's internal CMAKE_CXX_MODULE_MAP_FLAG is overridden so that the compile serves CMake's named-module map and
#   the source's header-unit map together (CMAKE-INTERNAL).
# * Mapper files spell CMIs relative to the top build dir ("$root ."), so depfiles name the same Ninja nodes, and are
#   written with "\n" line ends (NEWLINE_STYLE UNIX): GCC's mapper-file reader takes a "\r" as part of a word.
#
# The macros below run in the scope of the Core.cmake function that calls them (cmake_language(CALL _hu_GCC_...)).

include_guard(GLOBAL)

if(_HU_DIR MATCHES "[ \t]")
  message(FATAL_ERROR "HeaderUnits: with GCC the build directory must not contain spaces (GCC's module-mapper file parser cannot handle them).")
endif()

execute_process(COMMAND "${CMAKE_CXX_COMPILER}" -print-prog-name=g++-mapper-server
                OUTPUT_VARIABLE _hu_srv OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT IS_ABSOLUTE "${_hu_srv}" OR NOT EXISTS "${_hu_srv}")
  message(FATAL_ERROR "HeaderUnits: '${CMAKE_CXX_COMPILER} -print-prog-name=g++-mapper-server' gave '${_hu_srv}', not an existing file.")
endif()
set_property(GLOBAL PROPERTY _HU_GCC_SERVER "${_hu_srv}")
# hu-mapper, the mapper of a header unit's own compile: built once per build tree.  Natively with this compiler;
# cross-compiling with a host compiler (HU_HOST_CXX, else c++ / g++ / clang++ on the host's PATH), kept only if the
# result runs here.  With HU_GCC_WRAPPERS ON, or without a working host program, header units are compiled from
# wrappers (_hu_gcc_wrapper), which needs no program.
set(_hu_mapper "")
if(NOT HU_GCC_WRAPPERS)
  set(_hu_msrc "${CMAKE_CURRENT_LIST_DIR}/hu-mapper.cpp")
  set(_hu_mexe "${_HU_DIR}/hu-mapper")
  if(CMAKE_HOST_WIN32)
    string(APPEND _hu_mexe ".exe")
  endif()
  set(_hu_mcxx "")
  set(_hu_a1)
  if(NOT CMAKE_CROSSCOMPILING)
    set(_hu_mcxx "${CMAKE_CXX_COMPILER}")
    if(CMAKE_CXX_COMPILER_ARG1)
      separate_arguments(_hu_a1 NATIVE_COMMAND "${CMAKE_CXX_COMPILER_ARG1}")
    endif()
  elseif(HU_HOST_CXX)
    set(_hu_mcxx "${HU_HOST_CXX}")
  else()
    unset(_hu_found)                     # (find_program does not search when its variable is already set)
    find_program(_hu_found NAMES c++ g++ clang++ NO_CACHE NO_CMAKE_FIND_ROOT_PATH)
    if(_hu_found)
      set(_hu_mcxx "${_hu_found}")
    endif()
  endif()
  if(_hu_mcxx AND (NOT EXISTS "${_hu_mexe}" OR "${_hu_msrc}" IS_NEWER_THAN "${_hu_mexe}"))
    set(_hu_mflags -std=c++17 -O1 -static-libstdc++ -static-libgcc)
    if(CMAKE_HOST_WIN32)
      list(APPEND _hu_mflags -static)    # no DLLs to find when GCC starts it (Ninja's PATH may lack the compiler's bin)
    endif()
    file(MAKE_DIRECTORY "${_HU_DIR}")
    execute_process(COMMAND "${_hu_mcxx}" ${_hu_a1} ${_hu_mflags} -o "${_hu_mexe}" "${_hu_msrc}"
                    RESULT_VARIABLE _hu_rc OUTPUT_VARIABLE _hu_out ERROR_VARIABLE _hu_out)
    if(_hu_rc EQUAL 0 AND CMAKE_CROSSCOMPILING)
      # it must run on this host: an empty map and no requests
      file(WRITE "${_HU_DIR}/hu-mapper-check.map" "")
      execute_process(COMMAND "${_hu_mexe}" "${_HU_DIR}/hu-mapper-check.map" INPUT_FILE "${_HU_DIR}/hu-mapper-check.map"
                      RESULT_VARIABLE _hu_rc OUTPUT_VARIABLE _hu_o2 ERROR_VARIABLE _hu_o2)
      string(APPEND _hu_out "${_hu_o2}")
    endif()
    if(_hu_rc EQUAL 0)
      if(CMAKE_CROSSCOMPILING)
        message(STATUS "HeaderUnits: built ${_hu_mexe} with the host compiler ${_hu_mcxx}")
      else()
        message(STATUS "HeaderUnits: built ${_hu_mexe}")
      endif()
    else()
      file(REMOVE "${_hu_mexe}")
      message(WARNING "HeaderUnits: could not build hu-mapper with ${_hu_mcxx} (${_hu_rc}); header units are compiled "
        "from wrappers:\n${_hu_out}")
    endif()
  elseif(NOT _hu_mcxx)
    message(STATUS "HeaderUnits: cross-compiling without a host C++ compiler (HU_HOST_CXX): header units are compiled "
      "from wrappers")
  endif()
  if(_hu_mcxx AND EXISTS "${_hu_mexe}")
    set(_hu_mapper "${_hu_mexe}")
  endif()
endif()
set_property(GLOBAL PROPERTY _HU_GCC_MAPPER "${_hu_mapper}")
unset(_hu_mapper)
# Compile-time module mapper: CMake's per-TU .modmap (named modules) + this TU's header-unit map, if any.
# $1 = CMake's <MODULE_MAP_FILE>, $2 = the TU's source path (Ninja's $in; relative = inside the build dir).
if(CMAKE_HOST_WIN32)
  # Windows (MinGW): Ninja starts commands with CreateProcess, no shell, so the mapper is a cmd script.  $1 = CMake's
  # modmap, $2 = the TU's source.  The TU's header-unit map is looked up in src-index.txt ("<source>|<map>" per line,
  # _hu_gcc_src_map), read in the cmd process itself: maps have short names, as paths past 260 characters do not open.
  file(TO_NATIVE_PATH "${_hu_srv}" _hu_srv_native)
  file(TO_NATIVE_PATH "${_HU_DIR}/src-index.txt" _hu_index_native)
  file(CONFIGURE OUTPUT "${_HU_DIR}/gcc-mapper.cmd" @ONLY CONTENT [=[@echo off
rem Generated by HeaderUnits.cmake -- do not edit.
setlocal
set "s=%~f2"
set "m="
if exist "@_hu_index_native@" for /f "usebackq tokens=1,* delims=|" %%a in ("@_hu_index_native@") do if /i "%%a"=="%s%" set "m=%%b"
if not defined m goto plain
"@_hu_srv_native@" - "%~1" "%m%"
exit /b %errorlevel%
:plain
"@_hu_srv_native@" - "%~1"
exit /b %errorlevel%
]=] NEWLINE_STYLE CRLF)
  unset(_hu_srv_native)
  unset(_hu_index_native)
endif()
file(CONFIGURE OUTPUT "${_HU_DIR}/gcc-mapper.sh" @ONLY CONTENT [=[#!/bin/sh
# Generated by HeaderUnits.cmake -- do not edit.
case "$2" in /*) src="$2" ;; *) src="$PWD/$2" ;; esac
map="@_HU_DIR@/src$src.map"
if [ -f "$map" ]; then exec "@_hu_srv@" - "$1" "$map"; fi
exec "@_hu_srv@" - "$1"
]=] NEWLINE_STYLE UNIX)
# CMAKE-INTERNAL: CMAKE_CXX_MODULE_MAP_FLAG is CMake's private template for the GCC module-mapper option of
# its scanned compile rule (Modules/Compiler/GNU-CXX.cmake).  We replace "-fmodule-mapper=<MODULE_MAP_FILE>"
# by a mapper *program* (gcc-mapper.sh -> g++-mapper-server) that serves CMake's modmap PLUS the TU's
# header-unit map.  "$in" is a Ninja variable (the source of the compile edge) injected into CMake's rule;
# CMake writes sources as absolute paths, or relative to the top build dir when inside it (gcc-mapper.sh
# handles both).
set(_hu_old "${CMAKE_CXX_MODULE_MAP_FLAG}")
string(FIND "${_hu_old}" "-fmodule-mapper=<MODULE_MAP_FILE>" _hu_pos)
if(_hu_pos LESS 0)
  message(FATAL_ERROR "HeaderUnits: CMAKE_CXX_MODULE_MAP_FLAG='${_hu_old}' does not contain '-fmodule-mapper=<MODULE_MAP_FILE>'; "
    "this CMake version changed its internal GCC module rule, GCC header units cannot be supported.")
endif()
if(CMAKE_HOST_WIN32)
  # Double quotes (the compiler's own argv parsing) and $out.modmap instead of <MODULE_MAP_FILE>: CMake spells that one
  # with backslashes on Windows, which GCC's mapper-argument splitter takes as escapes.  CMAKE-INTERNAL (observed):
  # CMake's modmap is the object path plus ".modmap", and $out is the object alone (BMIs are dyndep outputs).
  string(REPLACE "-fmodule-mapper=<MODULE_MAP_FILE>"
         "\"-fmodule-mapper=|cmd /c ${_HU_DIR}/gcc-mapper.cmd $out.modmap $in\""
         CMAKE_CXX_MODULE_MAP_FLAG "${_hu_old}")
else()
  string(REPLACE "-fmodule-mapper=<MODULE_MAP_FILE>"
         "'-fmodule-mapper=|/bin/sh ${_HU_DIR}/gcc-mapper.sh <MODULE_MAP_FILE> $in'"
         CMAKE_CXX_MODULE_MAP_FLAG "${_hu_old}")
endif()
set_property(GLOBAL PROPERTY _HU_GCC_MAP_FLAG "${CMAKE_CXX_MODULE_MAP_FLAG}")
unset(_hu_old)
unset(_hu_pos)
unset(_hu_srv)

# The header-unit map of consumer source `src` (the per-TU mapper serves it): src/<path>.map (gcc-mapper.sh finds it
# by the source), or on Windows s/<hash>.map, listed in src-index.txt, which gcc-mapper.cmd reads (a name past 260
# characters would not open there).
function(_hu_gcc_src_map out hudir src)
  if(CMAKE_HOST_WIN32)
    string(MD5 h "${src}")
    string(SUBSTRING "${h}" 0 16 h)
    set(map "${hudir}/s/${h}.map")
    # Recorded here, written once by _hu_GCC_consumers_done.
    get_property(known GLOBAL PROPERTY _HU_GCC_SRC_INDEXED_${h} SET)
    if(NOT known)
      set_property(GLOBAL PROPERTY _HU_GCC_SRC_INDEXED_${h} 1)
      file(TO_NATIVE_PATH "${src}" nsrc)
      file(TO_NATIVE_PATH "${map}" nmap)
      set_property(GLOBAL APPEND_STRING PROPERTY _HU_GCC_SRC_INDEX "${nsrc}|${nmap}\n")
    endif()
    set(${out} "${map}" PARENT_SCOPE)
  else()
    set(${out} "${hudir}/src${src}.map" PARENT_SCOPE)
  endif()
endfunction()

# GCC names a header unit by its own spelling of the path, and the mapper is keyed by it.  For a compile whose search
# list is DIRS (normalized) / RAW (as spelled: an -I directory as given, GCC on Linux keeps "dir/../inc"), <name> is
# found in the first directory holding it: if that is the same file, the keys are that directory's spelling + "/<name>"
# and the normalized path; always <p> and the real path (a symbolic link, an 8.3 name); all for the same CMI.  An absolute name (a quote import found
# next to the importer) is its own key.
function(_hu_gcc_keys out p name)
  cmake_parse_arguments(PARSE_ARGV 3 A "" "" "DIRS;RAW")
  set(keys "${p}")
  file(REAL_PATH "${p}" rp)
  list(APPEND keys "${rp}")
  if(NOT IS_ABSOLUTE "${name}")
    foreach(d r IN ZIP_LISTS A_DIRS A_RAW)
      if(EXISTS "${d}/${name}" AND NOT IS_DIRECTORY "${d}/${name}")
        file(REAL_PATH "${d}/${name}" frp)
        if(frp STREQUAL rp)       # another file of that name (the compile's own <name>) is not this header unit
          set(n "${d}/${name}")
          cmake_path(NORMAL_PATH n)
          list(APPEND keys "${r}/${name}" "${n}")
        endif()
        break()
      endif()
    endforeach()
  endif()
  list(REMOVE_DUPLICATES keys)
  set(${out} "${keys}" PARENT_SCOPE)
endfunction()

# hu-mapper's map lines for building the header unit of <p> (found as <name> in DIRS / RAW) into <cmi>: the CMI to
# export, and every spelling GCC may use for an #include of the header itself (_hu_gcc_keys, plus the path relative to
# the build directory, as CMake passes a source inside it), to be kept textual.
function(_hu_gcc_self_lines out p name cmi)
  cmake_parse_arguments(PARSE_ARGV 4 A "" "" "DIRS;RAW")
  _hu_gcc_keys(keys "${p}" "${name}" DIRS ${A_DIRS} RAW ${A_RAW})
  string(FIND "${p}" "${CMAKE_BINARY_DIR}/" inbin)
  if(inbin EQUAL 0)
    file(RELATIVE_PATH rp "${CMAKE_BINARY_DIR}" "${p}")
    list(APPEND keys "${rp}" "./${rp}")
  endif()
  set(lines "$root .\n$export ${cmi}\n")
  foreach(k IN LISTS keys)
    string(APPEND lines "$textual ${k}\n")
  endforeach()
  set(${out} "${lines}" PARENT_SCOPE)
endfunction()

# Without hu-mapper: the source GCC compiles for header <p>: a wrapper in the build tree whose only line is #include "<p>".  The header
# unit is exported under the wrapper's name (its keys: the spellings GCC may use for it, as CMake passes a source in the
# build tree relative to it), and consumers' maps name the header itself: GCC does not check a header unit's name when
# it reads the CMI ("header units can be aliased").  So a header that includes itself through another one (fmt's
# core.h includes "format.h") stays a textual #include inside its own header unit: listed in its own mapper, GCC would
# import the header unit being built (a Ninja dependency cycle, then "depends on itself" once the CMI exists).
function(_hu_gcc_wrapper src_out keys_out hudir p)
  string(MD5 hh "${p}")
  string(SUBSTRING "${hh}" 0 16 hh)
  get_filename_component(fn "${p}" NAME)
  set(w "${hudir}/gcc/w/${hh}/${fn}")
  file(CONFIGURE OUTPUT "${w}" CONTENT "#include \"${p}\"\n" NEWLINE_STYLE UNIX)
  file(RELATIVE_PATH rw "${CMAKE_BINARY_DIR}" "${w}")
  file(REAL_PATH "${w}" rpw)
  set(keys "${w}" "${rpw}" "${rw}" "./${rw}")
  list(REMOVE_DUPLICATES keys)
  set(${src_out} "${w}" PARENT_SCOPE)
  set(${keys_out} "${keys}" PARENT_SCOPE)
endfunction()

# add_header_units(), per header: in: set, h, p (resolved path), oname, hudir; appends cmis, hmaps, maplines.
macro(_hu_GCC_add_header)
    # GCC: a header unit's identity is the path string; CMake passes the source as this absolute path.
    cmake_path(NORMAL_PATH p OUTPUT_VARIABLE np)
    if(NOT np STREQUAL p OR NOT IS_ABSOLUTE "${p}")
      message(FATAL_ERROR "add_header_units(${set}): GCC resolves <${h}> to '${p}', which is not a normalized absolute "
        "path. CMake would compile '${np}', a different header-unit identity for GCC. Not supported.")
    endif()
    if(p MATCHES "[ \t]")
      message(FATAL_ERROR "add_header_units(${set}): <${h}> resolves to '${p}' (contains a space); GCC's mapper files cannot express it.")
    endif()
    file(REAL_PATH "${p}" rpo)
    string(MD5 ok "${rpo}")
    get_property(owner GLOBAL PROPERTY _HU_REAL_SET_${ok})
    if(owner)
      message(FATAL_ERROR "add_header_units(${set}): <${h}> ('${p}') is already a header unit of set '${owner}'. "
        "With GCC a header has exactly one header unit per build tree (mapper and include translation are keyed by path).")
    endif()
    # The CMI IS the set's object file (-fmodule-only, like Clang's PCM): a real Ninja output, rebuilt when it
    # is deleted.  Mapper files spell it relative to the top build dir under "$root ." (CMake's own modmap
    # convention), so GCC's depfiles name the same Ninja node: an absolute spelling would be a different node, and
    # importers that know the CMI only from their depfile (CMake's synthesized BMI targets, #28166) would see a
    # header edit one ninja run late.  CMAKE-INTERNAL: object location, see the Clang branch below.
    set(cmi "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
    file(RELATIVE_PATH rcmi "${CMAKE_BINARY_DIR}" "${cmi}")
    if(CMAKE_HOST_WIN32)
      string(MD5 hh "${p}")
      string(SUBSTRING "${hh}" 0 16 hh)
      set(hmap "${hudir}/gcc/${hh}.map")   # short: a path past 260 characters would not open
    else()
      set(hmap "${hudir}/gcc/${set}/${oname}.map")
    endif()
    # Keys: the spellings GCC may use for this header with the set's search list (consumers get their own, at the end).
    _hu_gcc_keys(hkeys "${p}" "${h}" DIRS ${S_DIRS} RAW ${S_RAW})
    set(keys "")
    foreach(kk IN LISTS hkeys)
      string(APPEND keys "${kk} ${rcmi}\n")
    endforeach()
    # The header unit's own mapper makes GCC translate no #include inside it into an import (CMI content independent of
    # build order), not even one of the header itself: hu-mapper answers the export with the CMI and an #include of the
    # header (each spelling) with "textual"; without hu-mapper, the wrapper is compiled and only it is listed.
    get_property(mapper GLOBAL PROPERTY _HU_GCC_MAPPER)
    if(mapper)
      set(hsrc "${p}")
      _hu_gcc_self_lines(hlines "${p}" "${h}" "${rcmi}" DIRS ${S_DIRS} RAW ${S_RAW})
      set(mopt "-fmodule-mapper=|${mapper} ${hmap}")
    else()
      _hu_gcc_wrapper(hsrc wkeys "${hudir}" "${p}")
      set(hlines "$root .\n")
      foreach(kk IN LISTS wkeys)
        string(APPEND hlines "${kk} ${rcmi}\n")
      endforeach()
      set(mopt "-fmodule-mapper=${hmap}")
    endif()
    file(CONFIGURE OUTPUT "${hmap}" CONTENT "${hlines}" NEWLINE_STYLE UNIX)
    list(APPEND hmaps "${hmap}")
    string(APPEND maplines "${keys}")
    set_source_files_properties("${hsrc}" TARGET_DIRECTORY ${set} PROPERTIES
      LANGUAGE CXX
      OBJECT_NAME "hu/${oname}"
      # -Mno-modules: without it GCC's -MD depfile gets make rules for module names ("<hdr>.c++-module: <cmi>",
      # .PHONY) that Ninja records as never-existing inputs (always dirty).  Not -fdeps-format=p1689r5, which does the
      # same here but makes a compile without -M fail ("to generate dependencies you must specify either '-M' or
      # '-MM'"), as IDEs run these flags to read the compiler's settings (CLion).
      COMPILE_OPTIONS "-fmodules;-fmodule-header;-fmodule-only;${mopt};-Mno-modules")
    list(APPEND cmis "${cmi}")
endmacro()

# add_header_units(), after the headers: nothing for GCC (a header inside the build tree needs no launcher: the
# wrapper is what CMake compiles and what the header unit's own mapper names).
macro(_hu_GCC_finish_set)
endmacro()

# _hu_check_compat(): the consumer's directory must see the mapper override.
macro(_hu_GCC_check_compat)
    get_property(flag GLOBAL PROPERTY _HU_GCC_MAP_FLAG)
    get_directory_property(a DIRECTORY "${cdir}" DEFINITION CMAKE_CXX_MODULE_MAP_FLAG)
    if(NOT a STREQUAL flag)
      string(APPEND why "\n  CMAKE_CXX_MODULE_MAP_FLAG in the consumer's directory is not the HeaderUnits override "
                        "(include(HeaderUnits) must run in the top-level CMakeLists.txt before add_subdirectory())")
    endif()
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: one imported header unit (DEP_*) of header p: list it in p's mapper.
macro(_hu_GCC_header_import_dep)
    file(RELATIVE_PATH rdb "${CMAKE_BINARY_DIR}" "${DEP_BMI}")
    _hu_gcc_keys(dkeys "${DEP_PATH}" "${n}" DIRS ${sdirs} RAW ${sraws})
    foreach(kk IN LISTS dkeys)
      string(APPEND maplines "${kk} ${rdb}\n")
    endforeach()
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: write header p's mapper: its wrapper (_hu_gcc_wrapper), then its imports.
macro(_hu_GCC_header_import_done)
    list(GET hm ${i} hmap)
    file(RELATIVE_PATH rb0 "${CMAKE_BINARY_DIR}" "${b}")
    get_property(mapper GLOBAL PROPERTY _HU_GCC_MAPPER)
    if(mapper)
      _hu_gcc_self_lines(selfl "${p}" "${h}" "${rb0}" DIRS ${sdirs} RAW ${sraws})
    else()
      _hu_gcc_wrapper(wsrc wkeys "${hudir}" "${p}")
      set(selfl "$root .\n")
      foreach(kk IN LISTS wkeys)
        string(APPEND selfl "${kk} ${rb0}\n")
      endforeach()
    endif()
    file(CONFIGURE OUTPUT "${hmap}" CONTENT "${selfl}${maplines}" NEWLINE_STYLE UNIX)
endmacro()

# _hu_finalize(), per consumer source: in: t, src, tsets, hudir; appends opts and deps.
macro(_hu_GCC_consumer_options)
    if(src MATCHES "[ \t]")
      message(FATAL_ERROR "target_import_header_units(${t}): source path '${src}' contains a space; GCC's mapper cannot express it.")
    endif()
    get_property(srv GLOBAL PROPERTY _HU_GCC_SERVER)
    # Keys by the consumer's own search list: which directory (and so which spelling) GCC uses is the consumer's.
    string(MD5 tk "${t}")
    if(NOT DEFINED _hu_cs_${tk}_DIRS)
      _hu_target_search(_hu_cs_${tk} ${t})
      string(MD5 _hu_cs_${tk}_KEY "${_hu_cs_${tk}_DIRS}|${_hu_cs_${tk}_RAW}")
    endif()
    # The map's content depends only on the search list and the sets, so it is computed once per such pair (not per
    # source), and each header's keys once per search list: _hu_gcc_keys queries the file system.  (Variables of the
    # calling _hu_finalize_run, which runs once.)
    string(MD5 _hu_gck "${_hu_cs_${tk}_KEY}|${tsets}")
    if(NOT hu_textual AND DEFINED _hu_gc_${_hu_gck})
      set(content "${_hu_gc_${_hu_gck}}")
      list(APPEND deps ${_hu_gd_${_hu_gck}})
    else()
      set(content "")
      set(_hu_gdeps)
      foreach(s IN LISTS tsets)
        get_property(hs GLOBAL PROPERTY _HU_SET_${s}_HEADERS)
        get_property(ps GLOBAL PROPERTY _HU_SET_${s}_PATHS)
        get_property(c GLOBAL PROPERTY _HU_SET_${s}_CMIS)
        foreach(h p cmi IN ZIP_LISTS hs ps c)
          if(hu_textual AND NOT p IN_LIST hu_only)
            continue()          # "HeaderUnits pragma: textual-includes": not imported by this source
          endif()
          string(MD5 _hu_gkk "${_hu_cs_${tk}_KEY}|${p}|${h}")
          if(NOT DEFINED _hu_gk_${_hu_gkk})
            file(RELATIVE_PATH rc "${CMAKE_BINARY_DIR}" "${cmi}")
            _hu_gcc_keys(pkeys "${p}" "${h}" DIRS ${_hu_cs_${tk}_DIRS} RAW ${_hu_cs_${tk}_RAW})
            set(_hu_gk_${_hu_gkk} "")
            foreach(kk IN LISTS pkeys)
              string(APPEND _hu_gk_${_hu_gkk} "${kk} ${rc}\n")
            endforeach()
          endif()
          string(APPEND content "${_hu_gk_${_hu_gkk}}")
          list(APPEND _hu_gdeps "${cmi}")
        endforeach()
      endforeach()
      list(APPEND deps ${_hu_gdeps})
      if(NOT hu_textual)
        set(_hu_gc_${_hu_gck} "${content}")
        set(_hu_gd_${_hu_gck} "${_hu_gdeps}")
      endif()
    endif()
    _hu_gcc_src_map(smap "${hudir}" "${src}")
    file(CONFIGURE OUTPUT "${smap}" CONTENT "$root .\n${content}" NEWLINE_STYLE UNIX)
    # CMAKE-INTERNAL (observed): CMake's GCC scan rule passes no -fmodule-mapper of its own.
    # Dependency scan: this option lets the scan see the header
    # units (GCC must load them for their macros).  -f: unknown (named) modules get fallback names instead
    # of an error; the scan never reads named-module CMIs.  In the compile command this option is
    # overridden by the later mapper of CMAKE_CXX_MODULE_MAP_FLAG (gcc-mapper.sh serving the same map).
    list(APPEND opts "-fmodule-mapper=|${srv} -f - ${smap}")
endmacro()

# _hu_finalize(), after every consumer source: Windows: write src-index.txt (gcc-mapper.cmd reads it).
macro(_hu_GCC_consumers_done)
    if(CMAKE_HOST_WIN32)
      get_property(index GLOBAL PROPERTY _HU_GCC_SRC_INDEX)
      file(CONFIGURE OUTPUT "${hudir}/src-index.txt" CONTENT "${index}" NEWLINE_STYLE CRLF)
    endif()
endmacro()

