# HeaderUnits/MSVCNinja.cmake -- the MSVC strategy with Ninja (included by HeaderUnits.cmake when the C++ compiler is
# MSVC and the generator is not a Visual Studio one; there MSBuild builds header units itself, HeaderUnits/MSVC.cmake).
#
# * A header unit is identified by the resolved path of its header.  Its IFC is built with /exportHeader /ifcOnly and
#   written as the set's object file (/ifcOutput), so it is a real Ninja output, rebuilt when it is deleted (like GCC's
#   -fmodule-only CMI).  The header's own #includes stay textual (no /translateInclude there).
# * A consumer source gets /headerUnit "<path>=<ifc>" for each of its header units, and /translateInclude, in a
#   response file (one per distinct content): an import of the header, or an #include of it, uses the IFC.  The
#   dependency scan gets
#   "/translateInclude-" (see below).
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

# add_header_units(), per header: in: set, h, p, oname, hudir; appends cmis.
macro(_hu_MSVC_add_header)
    # CMAKE-INTERNAL: object location, see Clang.cmake.  With /ifcOnly cl writes no object; the IFC takes its place.
    set(cmi "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${set}.dir/hu/${oname}${CMAKE_CXX_OUTPUT_EXTENSION}")
    file(RELATIVE_PATH rcmi "${CMAKE_BINARY_DIR}" "${cmi}")
    set_source_files_properties("${p}" TARGET_DIRECTORY ${set} PROPERTIES
      LANGUAGE CXX
      OBJECT_NAME "hu/${oname}"
      COMPILE_OPTIONS "/exportHeader;/ifcOnly;/ifcOutput;${rcmi}")
    list(APPEND cmis "${cmi}")
endmacro()

# add_header_units(), after the headers: nothing to do for MSVC.
macro(_hu_MSVC_finish_set)
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
    file(CONFIGURE OUTPUT "${hrsp}" CONTENT "${maplines}" @ONLY)
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
    # A module interface unit: an importer of its module needs the header units it imports as well (cl looks them up
    # when it reads the module's IFC), whatever its own imports; they go to the target's INTERFACE_COMPILE_OPTIONS.
    if(NOT DEFINED _hu_mf_${tk})
      set(_hu_mf_${tk})
      get_target_property(msets ${t} CXX_MODULE_SETS)
      get_target_property(tsd ${t} SOURCE_DIR)
      foreach(ms IN LISTS msets)
        if(ms STREQUAL "CXX_MODULES")
          get_target_property(mfs ${t} CXX_MODULE_SET)
        else()
          get_target_property(mfs ${t} CXX_MODULE_SET_${ms})
        endif()
        foreach(mf IN LISTS mfs)
          cmake_path(ABSOLUTE_PATH mf BASE_DIRECTORY "${tsd}" NORMALIZE)
          list(APPEND _hu_mf_${tk} "${mf}")
        endforeach()
      endforeach()
    endif()
    if(src IN_LIST _hu_mf_${tk})
      get_property(known GLOBAL PROPERTY _HU_MSVC_IFACE_${tk} SET)
      if(NOT known)
        set_property(GLOBAL APPEND PROPERTY _HU_MSVC_IFACE_TARGETS "${t}")
      endif()
      set_property(GLOBAL APPEND_STRING PROPERTY _HU_MSVC_IFACE_${tk} "${rsp_lines}")   # (the mappings only)
    endif()
    string(APPEND rsp_lines "/translateInclude\n")   # an #include of a header with a header unit imports it
    # A response file, as with Clang: CMake runs some commands through cmd.exe (8191 characters).  Named by content.
    string(MD5 rk "${rsp_lines}")
    string(SUBSTRING "${rk}" 0 16 rk)
    set(rsp "${hudir}/rsp/${rk}.rsp")
    if(NOT DEFINED _hu_mw_${rk})
      set(_hu_mw_${rk} 1)
      file(CONFIGURE OUTPUT "${rsp}" CONTENT "${rsp_lines}" @ONLY)
    endif()
    list(APPEND opts "@${rsp}")
    list(APPEND deps "${rsp}")
endmacro()

# _hu_finalize(), after every consumer source: each target with module interface units that import header units gets
# their mappings in its INTERFACE_COMPILE_OPTIONS (one response file per target), and in its own COMPILE_OPTIONS: an
# importer whose options differ from the module's target makes CMake build a second BMI of the module for it.  Without
# /translateInclude a mapping changes no #include, so these targets' other sources stay as they were.
macro(_hu_MSVC_consumers_done)
    get_property(itargets GLOBAL PROPERTY _HU_MSVC_IFACE_TARGETS)
    foreach(it IN LISTS itargets)
      string(MD5 itk "${it}")
      get_property(ilines GLOBAL PROPERTY _HU_MSVC_IFACE_${itk})
      string(REPLACE "\n" ";" ilines "${ilines}")
      list(REMOVE_DUPLICATES ilines)
      list(REMOVE_ITEM ilines "")
      string(JOIN "\n" ilines ${ilines})
      string(SUBSTRING "${itk}" 0 16 irk)
      set(irsp "${hudir}/rsp/iface_${irk}.rsp")
      file(CONFIGURE OUTPUT "${irsp}" CONTENT "${ilines}\n" @ONLY)
      set_property(TARGET ${it} APPEND PROPERTY INTERFACE_COMPILE_OPTIONS "$<BUILD_INTERFACE:@${irsp}>")
      set_property(TARGET ${it} APPEND PROPERTY COMPILE_OPTIONS "@${irsp}")
    endforeach()
endmacro()
