+++
title = "Running the test suite per toolchain (gcc, clang, win, mingw), cheaply"
keys = [ "docker", "linux", "mingw", "run_suite", "tests", "wsl" ]
updated = "2026-11-18 21:17:31"
checked = "2026-11-18"

[[links]]
path = "tests/run_suite.cmake"
snippet = "elseif(TC STREQUAL \"mingw\")"
+++
cmake -DTC=<gcc|clang|win|mingw> -DCMAKE_EXE=<cmake> -DTAG=<tag> "-DTESTS=t01_stl;..." -P tests/run_suite.cmake; the table goes to _build/<tc>-<tag>/results.txt. Run only the tests a change touches (the user asked not to run everything each time).
- mingw: MINGW_CXX=C:/mingw64-gcc-16.1/bin/g++.exe, with that bin directory and a ninja on PATH (CLion's bundled ninja works), from a .bat run with cmd /c.
- Linux (gcc, clang): pipe the working tree into a throwaway container of the hu-toolchain:ext image in WSL (tar -cf - . | docker run -i --rm hu-toolchain:ext sh -c 'tar -xf - in /tmp ...'); never mount /mnt/c into Docker. From Git Bash, MSYS_NO_PATHCONV=1 keeps /mnt/c paths given to wsl intact.
- A consumer TU's GCC header-unit map is found in build.ninja as header_units/src/<path>.map, or header_units/s/<hash>.map on Windows.