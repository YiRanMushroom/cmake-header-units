+++
title = "GCC header unit's own compile: hu-mapper keeps a self-#include textual (wrappers as the fallback)"
kind = "design"
keys = [ "build tree header", "cross-compiling", "dependency cycle", "depends on itself", "fmt format.h", "hu-mapper", "hu_gcc_wrappers", "hu_host_cxx", "libcody", "mapper protocol", "self-include", "wrapper" ]
updated = "2026-11-19 00:22:30"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/hu-mapper.cpp"
snippet = "int main(int argc, char** argv) {"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_self_lines out p name cmi)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_wrapper src_out keys_out hudir p)"
+++
GCC's file mapper answers MODULE-EXPORT and INCLUDE-TRANSLATE from the same entry, so a header unit's own mapper listing the header made GCC import the header unit being built when the header includes itself through another one (fmt's core.h includes "format.h" when header-only; t21_self_include): the depfile names the CMI as its own input (Ninja cycle), and once the CMI exists the build fails with "depends on itself". Linux GCC behaves the same.
Now (user's choice over the wrapper): hu-mapper.cpp, a small libcody server (protocol: gcc/libcody/README.md; INCLUDE-TRANSLATE may answer "BOOL TRUE" = textual), built at configure time once per build tree with the project's compiler (-static-libstdc++ -static-libgcc, -static on Windows hosts; rebuilt if the source is newer). Header compile: -fmodule-mapper=|hu-mapper <map>; map: $root, $export <cmi> (answered whatever name GCC exports under, so build-tree headers need no launcher), $textual <each spelling of the header> (_hu_gcc_self_lines), plus "<path> <cmi>" for HU_ALLOW_HEADER_IMPORTS deps. Consumers keep GCC's g++-mapper-server (named modules untouched).
Cross-compiling: built with HU_HOST_CXX or c++/g++/clang++ found on the host (find_program NO_CMAKE_FIND_ROOT_PATH; its variable must be unset first or it does not search) and kept only if it runs. Else, or with HU_GCC_WRAPPERS ON: compile a wrapper (only #include "<p>") whose own map lists only the wrapper; GCC does not check a header unit's name on reading the CMI. Debug info identical (checked with DWARF decl_file/decl_line).