+++
title = "GCC header unit's own compile: hu-mapper keeps a self-#include textual (wrappers as the fallback)"
kind = "design"
keys = [ "build tree header", "cross-compiling", "dependency cycle", "depends on itself", "fmt format.h", "hu-mapper", "hu_gcc_wrappers", "hu_host_cxx", "libcody", "mapper protocol", "self-include", "wrapper" ]
updated = "2026-11-19 05:40:00"
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

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_line out)"
+++
GCC's file mapper answers MODULE-EXPORT and INCLUDE-TRANSLATE from the same entry, so a header unit's own mapper listing the header made GCC import the header unit being built when the header includes itself through another one (fmt's core.h includes "format.h" when header-only; t21_self_include): the depfile names the CMI as its own input (Ninja cycle), and once the CMI exists the build fails with "depends on itself". Linux GCC behaves the same.
Now (user's choice over the wrapper): hu-mapper.cpp, a small libcody server (protocol: gcc/libcody/README.md; INCLUDE-TRANSLATE may answer "BOOL TRUE" = textual), built at configure time once per build tree with the project's compiler (-static-libstdc++ -static-libgcc, -static on Windows hosts; rebuilt if the source is newer). Header compile: -fmodule-mapper=|hu-mapper <map>; map: $root, $export <cmi> (answered whatever name GCC exports under, so build-tree headers need no launcher), $textual <each spelling of the header> (_hu_gcc_self_lines), plus "<path> <cmi>" for HU_ALLOW_HEADER_IMPORTS deps. Consumers use it too (2026-11-19): compile "hu-mapper -c <modmap> hu-index.txt $in" (CMake's modmap for named modules + the source's map, found in the index; maps shared by content, gcc-m/<md5>.map), scan "hu-mapper -s <map>" (fallback names for unknown MODULE-EXPORT and MODULE-IMPORT, as g++-mapper-server -f; the scan of a module interface asks MODULE-EXPORT). No sh/cmd.exe in between. Without hu-mapper the scripts (gcc-mapper.sh / .cmd) + g++-mapper-server remain, on the same shared maps: they look $in up in hu-index.txt (exact match; CMake passes a compiled source by its absolute path, also inside the build tree).
Header paths with blanks (2026-11-19): probed with MinGW GCC 16.1 and Linux GCC 16.2, GCC quotes such names in requests (MODULE-IMPORT '/x/sp dir/inc/sp.hpp', a quote as \') and accepts a quoted PATHNAME; hu-mapper's words() reads map files with the same quoting, and _hu_gcc_line quotes a word with a blank or a quote for hu-mapper only. GCC's own reader (file mapper, g++-mapper-server) has no quoting (key = first word, value = rest of the line), so without hu-mapper a header path with blanks is a configure error (t21's space variant, a07_space_gcchdr_wrappers). Source paths and the build directory stay without blanks ($in and the mapper paths sit in the -fmodule-mapper argument).
Cross-compiling: built with HU_HOST_CXX or c++/g++/clang++ found on the host (find_program NO_CMAKE_FIND_ROOT_PATH; its variable must be unset first or it does not search) and kept only if it runs. Else, or with HU_GCC_WRAPPERS ON: compile a wrapper (only #include "<p>") whose own map lists only the wrapper; GCC does not check a header unit's name on reading the CMI. Debug info identical (checked with DWARF decl_file/decl_line).

Blanks in source and build directories (2026-11-20): GCC splits the -fmodule-mapper option at blanks with no quoting (probed: "|./logmap.exe one two" gives argv one, two; a relative program path works, resolved against the working directory, the top build dir for every Ninja command), and HELLO carries an empty ident ("HELLO 1 GCC ''"), so the compile's source cannot come from GCC. hu-mapper is therefore named ./CMakeFiles/header_units/hu-mapper, its maps and index relative to the top build dir, and "-c <modmap> <index>" reads the source from CMake's scan depfile <object>.ddi.d (first prerequisite, Makefile-escaped: "\ ", "\#", "$$"; Ninja keeps it, the scan rule has no deps). CMake writes a blank in an object name as "_" (src dir/x.cpp -> src_dir/x.cpp.o), so $out.modmap has a blank only when a target's binary directory has one (still rejected, _hu_gcc_objdir). t01_blank_dirs covers it on every toolchain.
