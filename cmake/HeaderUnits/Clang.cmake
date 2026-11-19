# HeaderUnits/Clang.cmake -- the Clang strategy (clang++ with the GNU-style driver, libstdc++, libc++ or the MSVC STL;
# clang-cl with the MSVC-style driver and the MSVC STL).
#
# * Lazy, named header units (Buck2-style): a module map declares the real header as the only header of module
#   <name>; the BMI (PCM) is the set's object file, built with -fmodule-name=<name> (without seeing the module map).
# * A consumer source gets -fmodule-map-file + -fmodule-file=<name>=<pcm> for each of its header units, in a
#   response file (one per distinct content, shared by sources with the same sets): every #include / import that
#   resolves to the header becomes an import of <name>,
#   and a PCM is only read by TUs that reach its header.
# * PCMs are spelled relative to the top build dir, so depfiles (-fmodule-file-deps) name the same Ninja nodes.
# * clang-cl gets the same options, those it has no cl spelling for with the /clang: prefix (_HU_CLANG_FWD).
#
# The macros below run in the scope of the Core.cmake function that calls them (cmake_language(CALL _hu_Clang_...)).

include_guard(GLOBAL)

# clang-cl (CMAKE_CXX_COMPILER_FRONTEND_VARIANT MSVC) takes the clang options it does not know as /clang:<option>:
# -fmodule-name, -fmodule-file-deps, and -o (clang-cl's own -o is cl's /o, which does not name a PCM).
if(CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
  set_property(GLOBAL PROPERTY _HU_CLANG_FWD "/clang:")
else()
  set_property(GLOBAL PROPERTY _HU_CLANG_FWD "")
endif()

# add_header_units(), per header: in: set, h, p, oname, hudir; appends cmis, mids, mmaps.
macro(_hu_Clang_add_header)
    # Clang: the "object" written by -fmodule-header ... -c is the header unit's PCM.
    file(REAL_PATH "${p}" p)
    # Source properties are per directory: a header in two sets of one directory gets ONE set of source
    # properties, so they must not depend on the set.  The module name and module map come from the path, and a
    # second set in the same directory reuses the first one's OBJECT_NAME.
    string(MD5 dk "${CMAKE_CURRENT_SOURCE_DIR}|${p}")
    get_property(prev_oname GLOBAL PROPERTY _HU_CLANG_ONAME_${dk})
    if(prev_oname)
      set(oname "${prev_oname}")
    else()
      set_property(GLOBAL PROPERTY _HU_CLANG_ONAME_${dk} "${oname}")
    endif()
    # Lazy, named header unit (Buck2-style, without stubs): a module map declares the REAL header as the only
    # header of module <mid>; consumers get -fmodule-map-file + -fmodule-file=<mid>=<pcm>, so every
    # #include / import that resolves to this file (any spelling) becomes an import of <mid>, and the PCM is
    # only read by TUs that actually reach the header.  The BMI's own compile must NOT see the module map
    # (Clang 22 then writes a PCM that crashes its consumers).
    string(MD5 ph "${p}")
    string(SUBSTRING "${ph}" 0 8 ph)
    get_filename_component(fn "${p}" NAME)
    string(MAKE_C_IDENTIFIER "hu_${ph}_${fn}" mid)
    set(mmap "${hudir}/clang/maps/${mid}.modulemap")
    file(CONFIGURE OUTPUT "${mmap}" CONTENT "module \"${mid}\" {\n  header \"${p}\"\n  export *\n}\n")
    list(APPEND mids "${mid}")
    list(APPEND mmaps "${mmap}")
    get_property(_hu_fwd GLOBAL PROPERTY _HU_CLANG_FWD)
    set(copts "-fmodule-header=system" "-xc++-system-header" "${_hu_fwd}-fmodule-name=${mid}")
    if(_hu_fwd)
      # clang-cl writes a header unit's PCM where /clang:-o says, not to /Fo (CMake's own clang-cl rule for a named
      # module's BMI, CMAKE_CXX_COMPILE_BMI, names it with -clang:-o too): the object path below, relative to the top
      # build dir.  The options are shared by every set of this directory with this header, so the set's directory is
      # spelled $<TARGET_PROPERTY:NAME>: the target that compiles it.
      file(RELATIVE_PATH od "${CMAKE_BINARY_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles")
      get_property(cfg GLOBAL PROPERTY _HU_CFG)
      list(APPEND copts "/clang:-o${od}/$<TARGET_PROPERTY:NAME>.dir/${cfg}hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
    endif()
    list(APPEND copts "-Wno-unused-command-line-argument")
    set_source_files_properties("${p}" TARGET_DIRECTORY ${set} PROPERTIES
      LANGUAGE CXX
      OBJECT_NAME "hu/${oname}"
      COMPILE_OPTIONS "${copts}")
    # CMAKE-INTERNAL: location of an object file (<target binary dir>/CMakeFiles/<target>.dir/<OBJECT_NAME><ext>
    # with the default CMAKE_INTERMEDIATE_DIR_STRATEGY=FULL).  Needed because OBJECT_DEPENDS does not accept
    # $<TARGET_OBJECTS> (and, for clang-cl, to name the PCM above).  If CMake ever places the object elsewhere, Ninja
    # stops with "missing and no known rule to make it" (loud failure, never a silent misbuild).
    get_property(cfg GLOBAL PROPERTY _HU_CFG)
    list(APPEND cmis "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/${cfg}hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
endmacro()

# add_header_units(), after the headers: nothing to do for Clang.
macro(_hu_Clang_finish_set)
endmacro()

# _hu_check_compat(): no Clang-specific checks.
macro(_hu_Clang_check_compat)
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: one imported header unit (DEP_*) of header p: its module map and PCM.
macro(_hu_Clang_header_import_dep)
    file(RELATIVE_PATH rb "${CMAKE_BINARY_DIR}" "${DEP_BMI}")
    list(APPEND opts "-fmodule-map-file=${DEP_MAP}" "-fmodule-file=${DEP_MID}=${rb}")
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: options of header p's own compile.
macro(_hu_Clang_header_import_done)
    get_property(_hu_fwd GLOBAL PROPERTY _HU_CLANG_FWD)
    list(APPEND opts "${_hu_fwd}-fmodule-file-deps" "-Wno-experimental-header-units")
endmacro()

# _hu_finalize(), after every consumer source: nothing to do for Clang.
macro(_hu_Clang_consumers_done)
endmacro()

# _hu_finalize(), per consumer source: in: t, src, tsets, sdk, hudir; appends opts and deps.
macro(_hu_Clang_consumer_options)
  # The response file depends only on the sets (and, for a "textual-includes" source, its imports): computed once per
  # set list and shared by the sources that have it, named by its content.  (Variables of the calling
  # _hu_finalize_run, which runs once.)
  string(MD5 _hu_ck "${tsets}")
  if(NOT hu_textual AND DEFINED _hu_cr_${_hu_ck})
    list(APPEND deps ${_hu_cd_${_hu_ck}})
    set(rsp "${_hu_cr_${_hu_ck}}")
  else()
    set(rsp_lines "")
    set(_hu_cdeps)
    foreach(s IN LISTS tsets)
      get_property(pcms GLOBAL PROPERTY _HU_SET_${s}_CMIS)
      get_property(mids GLOBAL PROPERTY _HU_SET_${s}_MIDS)
      get_property(mmaps GLOBAL PROPERTY _HU_SET_${s}_MMAPS)
      get_property(paths GLOBAL PROPERTY _HU_SET_${s}_PATHS)
      foreach(pp pcm mid mmap IN ZIP_LISTS paths pcms mids mmaps)
        if(hu_textual AND NOT pp IN_LIST hu_only)
          continue()          # "HeaderUnits pragma: textual-includes": not imported by this source
        endif()
        list(APPEND _hu_cdeps "${pcm}")
        # Spell the PCM relative to the top build dir (Ninja's cwd and node names): -fmodule-file-deps writes it
        # into the depfile as spelled, and an absolute spelling would be a different Ninja node (consumers would
        # only rebuild on the NEXT ninja run after a header edit).
        file(RELATIVE_PATH rpcm "${CMAKE_BINARY_DIR}" "${pcm}")
        foreach(arg "-fmodule-map-file=${mmap}" "-fmodule-file=${mid}=${rpcm}")
          string(REPLACE "\\" "\\\\" arg "${arg}")
          string(REPLACE "\"" "\\\"" arg "${arg}")
          string(APPEND rsp_lines "\"${arg}\"\n")
        endforeach()
      endforeach()
    endforeach()
    # The header-unit options go into a response file: CMake runs the dependency scan through cmd.exe on Windows
    # (8191 characters), and every header unit adds two long options.  The file is a dependency of the scan and
    # the compile (file(CONFIGURE) rewrites it only when its content changes).
    string(MD5 rk "${rsp_lines}")
    string(SUBSTRING "${rk}" 0 16 rk)
    get_property(cfg GLOBAL PROPERTY _HU_CFG)
    set(rsp "${hudir}/rsp/${cfg}${rk}.rsp")
    if(NOT DEFINED _hu_cw_${rk})
      set(_hu_cw_${rk} 1)
      _hu_write("${rsp}" "${rsp_lines}")
    endif()
    list(APPEND deps ${_hu_cdeps})
    if(NOT hu_textual)
      set(_hu_cr_${_hu_ck} "${rsp}")
      set(_hu_cd_${_hu_ck} "${_hu_cdeps}")
    endif()
  endif()
    get_property(_hu_fwd GLOBAL PROPERTY _HU_CLANG_FWD)
    list(APPEND opts "@${rsp}" "${_hu_fwd}-fmodule-file-deps" "-Wno-experimental-header-units" "-Wno-ambiguous-macro")
    list(APPEND deps "${rsp}")
endmacro()

