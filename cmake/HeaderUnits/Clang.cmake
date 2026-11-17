# HeaderUnits/Clang.cmake -- the Clang strategy (clang++ with the GNU-style driver; libstdc++ or the MSVC STL).
#
# * Lazy, named header units (Buck2-style): a module map declares the real header as the only header of module
#   <name>; the BMI (PCM) is the set's object file, built with -fmodule-name=<name> (without seeing the module map).
# * A consumer source gets -fmodule-map-file + -fmodule-file=<name>=<pcm> for each of its header units, in a
#   per-source response file: every #include / import that resolves to the header becomes an import of <name>,
#   and a PCM is only read by TUs that reach its header.
# * PCMs are spelled relative to the top build dir, so depfiles (-fmodule-file-deps) name the same Ninja nodes.
#
# The macros below run in the scope of the Core.cmake function that calls them (cmake_language(CALL _hu_Clang_...)).

include_guard(GLOBAL)

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
    set_source_files_properties("${p}" TARGET_DIRECTORY ${set} PROPERTIES
      LANGUAGE CXX
      OBJECT_NAME "hu/${oname}"
      COMPILE_OPTIONS "-fmodule-header=system;-xc++-system-header;-fmodule-name=${mid};-Wno-unused-command-line-argument")
    # CMAKE-INTERNAL: location of an object file (<target binary dir>/CMakeFiles/<target>.dir/<OBJECT_NAME><ext>
    # with the default CMAKE_INTERMEDIATE_DIR_STRATEGY=FULL).  Needed because OBJECT_DEPENDS does not accept
    # $<TARGET_OBJECTS>.  If CMake ever places the object elsewhere, Ninja stops with "missing and no known
    # rule to make it" (loud failure, never a silent misbuild).
    list(APPEND cmis "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
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
    list(APPEND opts "-fmodule-file-deps" "-Wno-experimental-header-units")
endmacro()

# _hu_finalize(), per consumer source: in: t, src, tsets, sdk, hudir; appends opts and deps.
macro(_hu_Clang_consumer_options)
    set(rsp_lines "")
    foreach(s IN LISTS tsets)
      get_property(pcms GLOBAL PROPERTY _HU_SET_${s}_CMIS)
      get_property(mids GLOBAL PROPERTY _HU_SET_${s}_MIDS)
      get_property(mmaps GLOBAL PROPERTY _HU_SET_${s}_MMAPS)
      foreach(pcm mid mmap IN ZIP_LISTS pcms mids mmaps)
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
      list(APPEND deps ${pcms})
    endforeach()
    # The header-unit options go into a response file: CMake runs the dependency scan through cmd.exe on Windows
    # (8191 characters), and every header unit adds two long options.  The file is a dependency of the scan and
    # the compile (file(CONFIGURE) rewrites it only when its content changes).
    string(SUBSTRING "${sdk}" 0 16 rk)
    get_filename_component(sn "${src}" NAME)
    set(rsp "${hudir}/rsp/${rk}_${sn}.rsp")
    file(CONFIGURE OUTPUT "${rsp}" CONTENT "${rsp_lines}" @ONLY)
    list(APPEND opts "@${rsp}" "-fmodule-file-deps" "-Wno-experimental-header-units" "-Wno-ambiguous-macro")
    list(APPEND deps "${rsp}")
endmacro()

