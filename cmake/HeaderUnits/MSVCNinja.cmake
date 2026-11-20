# HeaderUnits/MSVCNinja.cmake -- the MSVC strategy with Ninja (included by HeaderUnits.cmake when the C++ compiler is
# MSVC and the generator is not a Visual Studio one; there MSBuild builds header units itself, HeaderUnits/MSVC.cmake).
#
# * A header unit is identified by the resolved path of its header.  It is built with /exportHeader into the set's object
#   file and an IFC next to it (/ifcOutput), declared as a further output of that compile (OBJECT_OUTPUTS), so it is a
#   real Ninja output, rebuilt when it is deleted.  The object holds definitions that importers reference but do not
#   emit (static data members such as std::strong_ordering::less, <format>'s precision tables): every target that
#   imports the set links it (_hu_MSVC_consumers_done).  The header's own #includes stay textual (no /translateInclude
#   there).  A header in two sets of one directory has one set of source properties, so they do not depend on the set
#   (as in Clang.cmake).
# * A consumer source gets /headerUnit "<path>=<ifc>" for each of its header units, and /translateInclude, in a
#   response file (one per distinct content): an import of the header, or an #include of it, uses the IFC.  The
#   dependency scan gets
#   "/translateInclude-" (see below).
# * An IFC also depends on the compiler and on a file that records the toolchain (see below): Ninja keeps no header of
#   the C++ library or the Windows SDK in its dependencies.
# * IFCs are spelled relative to the top build dir (Ninja's working directory).
# * CMake's own module scan (cl /scanDependencies) accepts an import of a header unit; it gets the same options.
#
# The macros below run in the scope of the Core.cmake function that calls them (cmake_language(CALL _hu_MSVC_...)).

include_guard(GLOBAL)

# CMAKE-INTERNAL: CMAKE_CXX_SCANDEP_SOURCE is CMake's private template of its dependency-scan rule
# (Modules/Compiler/MSVC-CXX.cmake).  "/translateInclude-" is appended there: a consumer's response file has
# /translateInclude, and per-source options reach the scan as well, where cl /scanDependencies with /translateInclude
# recurses without end into a header that includes itself through another one (fmt's core.h; t21).  The scan needs no
# translation (CMake reads only named modules from it).
if(NOT CMAKE_CXX_SCANDEP_SOURCE MATCHES "-scanDependencies")
  message(FATAL_ERROR "HeaderUnits: CMAKE_CXX_SCANDEP_SOURCE='${CMAKE_CXX_SCANDEP_SOURCE}' is not cl's -scanDependencies "
    "rule; this CMake version changed its internal MSVC scan rule, MSVC header units cannot be supported.")
endif()
string(APPEND CMAKE_CXX_SCANDEP_SOURCE " /translateInclude-")
set_property(GLOBAL PROPERTY _HU_MSVC_SCAN_RULE "${CMAKE_CXX_SCANDEP_SOURCE}")

# Ninja's msvc deps (/showIncludes) leave out every header whose path holds "Program Files" or "Microsoft Visual
# Studio", so no header of the C++ library or the Windows SDK is a dependency of anything.  Every header unit depends
# instead on the compiler (an update of Visual Studio may replace it in its directory) and on a file that records the
# compiler, its version and the INCLUDE environment variable (cl's system include directories, which name the toolset
# and the Windows SDK).  Each CMake run writes the file, and only when its content changes.
set(_hu_include "$ENV{INCLUDE}")
file(CONFIGURE OUTPUT "${_HU_DIR}/msvc-toolchain.txt" CONTENT
  "CMAKE_CXX_COMPILER=@CMAKE_CXX_COMPILER@\nCMAKE_CXX_COMPILER_VERSION=@CMAKE_CXX_COMPILER_VERSION@\nINCLUDE=@_hu_include@\n"
  @ONLY)
unset(_hu_include)
set_property(GLOBAL PROPERTY _HU_MSVC_TOOLCHAIN_DEPS "${_HU_DIR}/msvc-toolchain.txt" "${CMAKE_CXX_COMPILER}")

# add_header_units(), per header: in: set, h, p, oname, hudir; appends cmis.
macro(_hu_MSVC_add_header)
    # Source properties are per directory: a header in two sets of one directory gets ONE set of source properties,
    # which the last set would otherwise overwrite (its OBJECT_NAME, and an /ifcOutput naming its own directory, so
    # every set's compile writes that set's IFC).  A second set in the same directory reuses the first one's
    # OBJECT_NAME (the header may be spelled differently there), keyed by the real path (two spellings of one file
    # that CMake takes for two sources only share an object name, which is harmless).
    file(REAL_PATH "${p}" rpo)
    string(MD5 dk "${CMAKE_CURRENT_SOURCE_DIR}|${rpo}")
    get_property(prev_oname GLOBAL PROPERTY _HU_MSVC_ONAME_${dk})
    if(prev_oname)
      set(oname "${prev_oname}")
    else()
      set_property(GLOBAL PROPERTY _HU_MSVC_ONAME_${dk} "${oname}")
    endif()
    # CMAKE-INTERNAL: object location, see Clang.cmake.  file(RELATIVE_PATH): the IFC is named relative to the top
    # build dir (Ninja's working directory).
    file(RELATIVE_PATH od "${CMAKE_BINARY_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles")
    set(obj "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
    get_property(tcdeps GLOBAL PROPERTY _HU_MSVC_TOOLCHAIN_DEPS)
    if(NOT prev_oname)
      # The usual case: /exportHeader writes the object (the header unit's definitions, linked by every importer) and
      # the IFC next to it, "<object name>.ifc", declared as a further output of the compile.
      set(cmi "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/hu/${oname}.ifc")
      set_source_files_properties("${p}" TARGET_DIRECTORY ${set} PROPERTIES
        LANGUAGE CXX
        OBJECT_NAME "hu/${oname}"
        OBJECT_DEPENDS "${tcdeps}"
        OBJECT_OUTPUTS "${cmi}"
        COMPILE_OPTIONS "/exportHeader;/ifcOutput;${od}/${set}.dir/hu/${oname}.ifc")
      set_source_files_properties("${obj}" DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" PROPERTIES GENERATED TRUE EXTERNAL_OBJECT TRUE)
      set_property(GLOBAL APPEND PROPERTY _HU_SET_${set}_OBJS "${obj}")
      set_property(GLOBAL PROPERTY _HU_MSVC_FIRST_${dk} "${set}|${cmi}|${obj}")
    else()
      # The same header in a second set of this directory: OBJECT_OUTPUTS cannot name a file per target, so for this
      # header every set of the directory builds only the IFC (/ifcOnly), written as the set's object file
      # ($<TARGET_PROPERTY:NAME>: the target that compiles it).  No object holds its definitions (README, Limitations).
      set(cmi "${obj}")
      set_source_files_properties("${p}" TARGET_DIRECTORY ${set} PROPERTIES
        OBJECT_OUTPUTS ""
        COMPILE_OPTIONS "/exportHeader;/ifcOnly;/ifcOutput;${od}/$<TARGET_PROPERTY:NAME>.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
      get_property(first GLOBAL PROPERTY _HU_MSVC_FIRST_${dk})
      if(first)
        set_property(GLOBAL PROPERTY _HU_MSVC_FIRST_${dk} "")
        string(REPLACE "|" ";" first "${first}")
        list(GET first 0 fset)
        list(GET first 1 fifc)
        list(GET first 2 fobj)
        get_property(fc GLOBAL PROPERTY _HU_SET_${fset}_CMIS)
        list(FIND fc "${fifc}" fi)
        if(fi GREATER -1)
          list(REMOVE_AT fc ${fi})
          list(INSERT fc ${fi} "${fobj}")
        endif()
        set_property(GLOBAL PROPERTY _HU_SET_${fset}_CMIS "${fc}")
        get_property(fo GLOBAL PROPERTY _HU_SET_${fset}_OBJS)
        list(REMOVE_ITEM fo "${fobj}")
        set_property(GLOBAL PROPERTY _HU_SET_${fset}_OBJS "${fo}")
      endif()
    endif()
    list(APPEND cmis "${cmi}")
endmacro()

# _hu_check_compat(): the consumer's directory must see the scan-rule override.
macro(_hu_MSVC_check_compat)
    get_property(flag GLOBAL PROPERTY _HU_MSVC_SCAN_RULE)
    get_directory_property(a DIRECTORY "${cdir}" DEFINITION CMAKE_CXX_SCANDEP_SOURCE)
    if(NOT a STREQUAL flag)
      string(APPEND why "\n  CMAKE_CXX_SCANDEP_SOURCE in the consumer's directory is not the HeaderUnits override "
                        "(include(HeaderUnits) must run in the top-level CMakeLists.txt before add_subdirectory())")
    endif()
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: one imported header unit (DEP_*) of header p: a line of p's response file
# (source COMPILE_OPTIONS take no SHELL: groups, and a repeated "/headerUnit" would be de-duplicated).
macro(_hu_MSVC_header_import_dep)
    file(RELATIVE_PATH rb "${CMAKE_BINARY_DIR}" "${DEP_BMI}")
    file(TO_NATIVE_PATH "${DEP_PATH}" np)
    string(APPEND maplines "/headerUnit \"${np}=${rb}\"\n")
endmacro()

# _hu_finalize(), HU_ALLOW_HEADER_IMPORTS: options of header p's own compile.
macro(_hu_MSVC_header_import_done)
    string(MD5 hrk "${p}")
    string(SUBSTRING "${hrk}" 0 16 hrk)
    set(hrsp "${hudir}/rsp/h_${hrk}.rsp")
    _hu_write("${hrsp}" "${maplines}" BOM)
    list(APPEND opts "@${hrsp}")
    list(APPEND deps "${hrsp}")
endmacro()

# _hu_finalize(), per consumer source: in: t, src, tsets, sdk, hudir; appends opts and deps.
macro(_hu_MSVC_consumer_options)
    string(MD5 tk "${t}")
    # The mappings depend only on the sets (and, for a "textual-includes" source, its imports): computed once per set
    # list; the response file is shared by the sources that have the same content.  (Variables of the calling
    # _hu_finalize_run, which runs once.)
    string(MD5 _hu_mk "${tsets}")
    if(NOT hu_textual AND DEFINED _hu_ml_${_hu_mk})
      set(rsp_lines "${_hu_ml_${_hu_mk}}")
      list(APPEND deps ${_hu_md_${_hu_mk}})
    else()
      set(rsp_lines "")
      set(_hu_mdeps)
      foreach(s IN LISTS tsets)
        get_property(ps GLOBAL PROPERTY _HU_SET_${s}_PATHS)
        get_property(c GLOBAL PROPERTY _HU_SET_${s}_CMIS)
        foreach(pp cmi IN ZIP_LISTS ps c)
          if(hu_textual AND NOT pp IN_LIST hu_only)
            continue()          # "HeaderUnits pragma: textual-includes": not imported by this source
          endif()
          file(RELATIVE_PATH rc "${CMAKE_BINARY_DIR}" "${cmi}")
          file(TO_NATIVE_PATH "${pp}" np)
          string(APPEND rsp_lines "/headerUnit \"${np}=${rc}\"\n")
          list(APPEND _hu_mdeps "${cmi}")
        endforeach()
      endforeach()
      list(APPEND deps ${_hu_mdeps})
      if(NOT hu_textual)
        set(_hu_ml_${_hu_mk} "${rsp_lines}")
        set(_hu_md_${_hu_mk} "${_hu_mdeps}")
      endif()
    endif()
    # The mappings of this source, for _hu_MSVC_consumers_done (a module interface unit's importers need them).
    string(MD5 _hu_sk "${src}")
    set_property(GLOBAL PROPERTY _HU_MSVC_LINES_${_hu_sk} "${rsp_lines}")
    string(APPEND rsp_lines "/translateInclude\n")   # an #include of a header with a header unit imports it
    # A response file, as with Clang: CMake runs some commands through cmd.exe (8191 characters).  Named by content.
    string(MD5 rk "${rsp_lines}")
    string(SUBSTRING "${rk}" 0 16 rk)
    set(rsp "${hudir}/rsp/${rk}.rsp")
    _hu_write("${rsp}" "${rsp_lines}" ONCE BOM)
    list(APPEND opts "@${rsp}")
    list(APPEND deps "${rsp}")
endmacro()

# _hu_finalize(), after every consumer source: each target with module interface units that import header units gets
# their mappings in its INTERFACE_COMPILE_OPTIONS (one response file per target), and in its own COMPILE_OPTIONS: an
# importer whose options differ from the module's target makes CMake build a second BMI of the module for it.  Without
# /translateInclude a mapping changes no #include, so these targets' other sources stay as they were.  Done over every
# (target, source) of Core.cmake: _hu_MSVC_consumer_options runs once per (directory, source), so for a module source of
# two targets of one directory only for the first (cl looks the header units up when it reads the module's IFC, so the
# importers of both targets need them).
macro(_hu_MSVC_consumers_done)
    get_property(_hu_tus GLOBAL PROPERTY _HU_TUS)
    set(_hu_itargets)
    set(_hu_ltargets)
    foreach(_hu_tu IN LISTS _hu_tus)
      string(FIND "${_hu_tu}" "|" _hu_bar)
      string(SUBSTRING "${_hu_tu}" 0 ${_hu_bar} _hu_t)
      math(EXPR _hu_bar "${_hu_bar} + 1")
      string(SUBSTRING "${_hu_tu}" ${_hu_bar} -1 _hu_src)
      string(MD5 _hu_tk "${_hu_t}")
      # The sets whose objects the target links: its sources' sets and, with HU_ALLOW_HEADER_IMPORTS, the sets their
      # headers import.
      if(NOT DEFINED _hu_ls_${_hu_tk})
        list(APPEND _hu_ltargets "${_hu_t}")
        set(_hu_ls_${_hu_tk})
      endif()
      string(MD5 _hu_tuk "${_hu_tu}")
      get_property(_hu_ss GLOBAL PROPERTY _HU_TU_${_hu_tuk}_SETS)
      while(_hu_ss)
        list(POP_FRONT _hu_ss _hu_s)
        if(NOT _hu_s IN_LIST _hu_ls_${_hu_tk})
          list(APPEND _hu_ls_${_hu_tk} "${_hu_s}")
          get_property(_hu_ds GLOBAL PROPERTY _HU_SET_${_hu_s}_DEPSETS)
          list(APPEND _hu_ss ${_hu_ds})
        endif()
      endwhile()
      if(NOT DEFINED _hu_mf_${_hu_tk})      # the target's module interface units
        set(_hu_mf_${_hu_tk})
        get_target_property(msets ${_hu_t} CXX_MODULE_SETS)
        get_target_property(tsd ${_hu_t} SOURCE_DIR)
        foreach(ms IN LISTS msets)
          if(ms STREQUAL "CXX_MODULES")
            get_target_property(mfs ${_hu_t} CXX_MODULE_SET)
          else()
            get_target_property(mfs ${_hu_t} CXX_MODULE_SET_${ms})
          endif()
          foreach(mf IN LISTS mfs)
            cmake_path(ABSOLUTE_PATH mf BASE_DIRECTORY "${tsd}" NORMALIZE)
            list(APPEND _hu_mf_${_hu_tk} "${mf}")
          endforeach()
        endforeach()
      endif()
      if(NOT _hu_src IN_LIST _hu_mf_${_hu_tk})
        continue()
      endif()
      string(MD5 _hu_sk "${_hu_src}")
      get_property(_hu_l GLOBAL PROPERTY _HU_MSVC_LINES_${_hu_sk})   # (unset: a textual TU that imports nothing)
      if(NOT DEFINED _hu_il_${_hu_tk})
        list(APPEND _hu_itargets "${_hu_t}")
        set(_hu_il_${_hu_tk} "")
      endif()
      string(APPEND _hu_il_${_hu_tk} "${_hu_l}")
    endforeach()
    foreach(it IN LISTS _hu_itargets)
      string(MD5 itk "${it}")
      string(REPLACE "\n" ";" ilines "${_hu_il_${itk}}")
      list(REMOVE_DUPLICATES ilines)
      list(REMOVE_ITEM ilines "")
      string(JOIN "\n" ilines ${ilines})
      string(SUBSTRING "${itk}" 0 16 irk)
      set(irsp "${hudir}/rsp/iface_${irk}.rsp")
      _hu_write("${irsp}" "${ilines}\n" BOM)
      set_property(TARGET ${it} APPEND PROPERTY INTERFACE_COMPILE_OPTIONS "$<BUILD_INTERFACE:@${irsp}>")
      set_property(TARGET ${it} APPEND PROPERTY COMPILE_OPTIONS "@${irsp}")
    endforeach()
    # Each target that imports a set links the objects of its header units (their definitions; _HU_SET_<set>_OBJS, not
    # $<TARGET_OBJECTS>: a header of two sets of one directory has only an IFC there), as sources (no
    # target_link_libraries: its plain and keyword signatures cannot be mixed on a target).  An object library passes
    # them on to the targets that link it (INTERFACE_SOURCES).
    foreach(lt IN LISTS _hu_ltargets)
      string(MD5 ltk "${lt}")
      get_target_property(ltype ${lt} TYPE)
      foreach(ls IN LISTS _hu_ls_${ltk})
        get_property(lobjs GLOBAL PROPERTY _HU_SET_${ls}_OBJS)
        if(NOT lobjs)
          continue()
        endif()
        if(ltype STREQUAL "OBJECT_LIBRARY")
          set_property(TARGET ${lt} APPEND PROPERTY INTERFACE_SOURCES ${lobjs})
        else()
          set_property(TARGET ${lt} APPEND PROPERTY SOURCES ${lobjs})
        endif()
      endforeach()
    endforeach()
endmacro()
