+++
title = "GCC on Windows (MinGW-w64): how header units are mapped without a POSIX shell, and why"
keys = [ "crlf", "gcc", "mapper", "max_path", "mingw", "windows" ]
updated = "2026-11-19 05:40:00"
checked = "2026-11-19"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "gcc-mapper.cmd $out.modmap $in"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "file(TO_NATIVE_PATH \"${_HU_DIR}/hu-index.txt\" _hu_index_native)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "file(CONFIGURE OUTPUT \"${smap}\" CONTENT \"$root .\\n${content}\" NEWLINE_STYLE UNIX)"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "list(APPEND _hu_mflags -static)"
+++
With hu-mapper (the normal case) consumers need no script (gcc.wrapper), so paths may hold , ; = etc. Without it: Ninja on Windows starts commands with CreateProcess (no /bin/sh), so the consumer mapper is a generated gcc-mapper.cmd run as "-fmodule-mapper=|cmd /c <dir>/gcc-mapper.cmd $out.modmap $in" (double quotes: GCC splits the mapper argument itself; forward slashes, as libiberty's splitter eats backslashes; $out.modmap because CMake spells <MODULE_MAP_FILE> with backslashes there). Found the hard way:
- Every mapper file must be written NEWLINE_STYLE UNIX: GCC's mapper-file reader keeps the \r of CRLF as part of the CMI path, and every header unit then fails with "unknown compiled module interface: no such module".
- Map files have short names (gcc/<md5-16>.map, gcc-m/<md5-16>.map found through hu-index.txt, which the .cmd reads as hu-mapper does: exact match of $in): a name built from the source path passed 260 characters and did not open.
- Headers inside the build tree need no launcher (gcc.wrapper: hu-mapper answers the export whatever the name); gcc-abs-src.sh is gone. hu-mapper.exe is linked -static so GCC can start it without the compiler's bin on PATH.
- Open on MinGW (also with the older try_compile code): t02_thirdparty fails to link (fmt's function-local static arrays in inline functions: multiple definition between the header unit and #include in another TU). t08_auto (fmt's self-include) is fixed (gcc.wrapper).