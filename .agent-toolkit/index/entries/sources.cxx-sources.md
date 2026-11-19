+++
title = "A target's C++ sources: one function for the scan and the header units, by what CMake compiles as C++"
keys = [ "cxx_module_set", "generator expression", "get_source_file_property", "header_file_only", "language", "relative path", "sources", "target_objects" ]
updated = "2026-11-19 23:30:00"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_target_cxx_sources out tgt)"

[[items]]
name = "pinning"
value = "A source lookup by an absolute path (get_source_file_property, set_property(SOURCE)) of a source listed by a relative path fixes its directory to that path's (cmSourceFileLocation::Matches calls Update): reading sdir/x of a file that is only in the build directory makes the generate step fail with 'Cannot find source file'. With TARGET_DIRECTORY or DIRECTORY a relative path is made absolute against the current source directory, so it pins too. Hence the lookup uses the path CMake finds (_hu_source_path). Not handled: CMP0115 OLD extension guessing (an extension-less name would be pinned to the build directory) and a GENERATED source with a same-named file in the source directory."
path = "cmake/HeaderUnits/Common.cmake"
snippet = "function(_hu_source_path out s sdir bdir)"

[[items]]
name = "language"
value = "get_source_file_property(LANGUAGE) returns the language CMake determines (the property, else the extension via the enabled languages). It returns NOTFOUND when the target's directory has no source object yet: module file-set files, and sources added by target_sources from another directory. Then the extension is checked against CMAKE_CXX_SOURCE_FILE_EXTENSIONS (4.5: C;M;c++;cc;cpp;cxx;mm;mpp;CPP;ixx;cppm;ccm;cxxm;c++m). A LANGUAGE CXX .c file gets -x c++ (or /TP) in FLAGS, the same on the scan and compile edges. HEADER_FILE_ONLY sources are not compiled."
+++
_hu_target_cxx_sources (Common.cmake) gives a target's C++ sources: its SOURCES and CXX_MODULES file sets, the ones CMake compiles as C++ (item language), absolute, each once. It is used by target_auto_header_units and target_header_units_scan_sources (the sources to scan, Auto.cmake _hu_auto_inputs) and by target_import_header_units (the sources that get the options, Core.cmake _hu_finalize_run). Before, Auto had its own copy, which was the cause of these bugs:
- A generator-expression entry was a FATAL in Common, also through target_auto_header_units, which ends in target_import_header_units. So any target with $<TARGET_OBJECTS:...> or a configuration's source failed. Now such entries are skipped in both places: they are evaluated only at generate time.
- Auto resolved a relative path to the source directory only. So a build-directory source (a configure_file output listed by name) was not scanned, and target_header_units_scan_sources rejected it.
- Both used the same hand-written extension list (no CPP, M, mm), and neither read LANGUAGE or HEADER_FILE_ONLY.

Probed with CMake 4.5.0:
- CXX_MODULE_SET_CXX_MODULES returns the default set's files, the same as CXX_MODULE_SET. That alias is undocumented, so the code reads CXX_MODULE_SET.
- CMake finds a relative source in the source directory, else in the build directory. An existing configure_file output needs no GENERATED property; a custom-command output is in the build directory.
- CMake rejects a CXX_MODULES file-set entry that is not CXX ("not classified as a \"CXX\" source") or is HEADER_FILE_ONLY ("not scheduled for compilation").
- File-set FILES may be generator expressions.

Explicit names (target_header_units_scan_sources, target_import_header_units SOURCES) are resolved at the call with _hu_source_path in the calling directory. So a generated source given by name keeps the "does not exist at configure time" message. t28 covers all of this, and fails on every case with the code before.

Not handled: INTERFACE_SOURCES of linked libraries are compiled into the consumer, but neither command sees them.
