+++
title = "GCC on Windows (MinGW-w64): how header units are mapped without a POSIX shell, and why"
keys = [ "crlf", "gcc", "mapper", "max_path", "mingw", "windows" ]
updated = "2026-11-18 21:17:30"
checked = "2026-11-18"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "gcc-mapper.cmd $out.modmap $in"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_src_map out hudir src)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "file(CONFIGURE OUTPUT \"${smap}\" CONTENT \"$root .\\n${content}\" NEWLINE_STYLE UNIX)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "a header unit of a header in the build tree is not supported yet"
+++
Ninja on Windows starts commands with CreateProcess (no /bin/sh), so the consumer mapper is a generated gcc-mapper.cmd run as "-fmodule-mapper=|cmd /c <dir>/gcc-mapper.cmd $out.modmap $in" (double quotes: GCC splits the mapper argument itself; forward slashes, as libiberty's splitter eats backslashes; $out.modmap because CMake spells <MODULE_MAP_FILE> with backslashes there). Found the hard way:
- Every mapper file must be written NEWLINE_STYLE UNIX: GCC's mapper-file reader keeps the \r of CRLF as part of the CMI path, and every header unit then fails with "unknown compiled module interface: no such module".
- Map files have short names (gcc/<md5-16>.map, s/<md5-16>.map listed in src-index.txt, which the .cmd reads): a name built from the source path passed 260 characters and did not open.
- A header inside the build tree is a FATAL_ERROR on Windows (it needs gcc-abs-src.sh), so t12_build_tree cannot pass with TC=mingw.