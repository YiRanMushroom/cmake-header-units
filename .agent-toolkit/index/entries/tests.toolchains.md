+++
title = "Running the test suite per toolchain (gcc, clang, win, clangcl, mingw, msvc), cheaply"
keys = [ "docker", "linux", "mingw", "run_suite", "tests", "wsl" ]
updated = "2026-11-19 05:40:00"
checked = "2026-11-19"

[[links]]
path = "tests/run_suite.cmake"
snippet = "elseif(TC STREQUAL \"mingw\")"
+++
cmake -DTC=<gcc|clang|win|clangcl|mingw|msvc> -DCMAKE_EXE=<cmake> -DTAG=<tag> "-DTESTS=t01_stl;..." -P tests/run_suite.cmake; the table goes to _build/<tc>-<tag>/results.txt. Run only the tests a change touches (the user asked not to run everything each time). TESTS items are name prefixes ("t01" for t01_stl); an unknown one aborts the whole run with no results.txt. Known failures (mingw: t02; msvc: t02, t08, t11, fmt link) are reported as XFAIL (XPASS if it starts passing). The tests read the module live: don't edit cmake/ while a Windows run is going.
- mingw: MINGW_CXX=C:/mingw64-gcc-16.1/bin/g++.exe, with that bin directory and a ninja on PATH (CLion's bundled ninja works), from a .bat run with cmd /c.
- win (clang++ + MSVC STL): run-win.bat calls vcvars64.bat, which puts Visual Studio's own Clang 19.1.5 first on PATH (it cannot build library header units with SDK 10.0.26100): set CLANG_CXX to the Clang 22 clang++.exe (run-win.bat passes it on).
- msvc (MSVC + Ninja): run-msvc-ninja.bat, or vcvars64.bat then TC=msvc.
- clangcl (clang-cl + MSVC STL): run-clangcl.bat, or vcvars64.bat then TC=clangcl; CLANG_CXX to the Clang 22 clang-cl.exe, as for win. Facts in clang.clang-cl.
- Use one ninja per build tree: another version's `ninja -t deps` resets .ninja_log ("build log version is too old; starting over").
- Linux (gcc, clang): pipe the working tree into a throwaway container of the hu-toolchain:ext image in WSL (tar -cf - . | docker run -i --rm hu-toolchain:ext sh -c 'tar -xf - in /tmp ...'); never mount /mnt/c into Docker. run-linux.sh writes each toolchain's log to _build/run-<tc>.txt inside the container (print it when results.txt is missing). *.sh must be LF (.gitattributes), or sh fails in the container. From Git Bash, MSYS_NO_PATHCONV=1 keeps /mnt/c paths given to wsl intact.
- A consumer TU's GCC header-unit map is found in build.ninja as header_units/gcc-m/<hash>.map (hu-index.txt names each source's map).
- GCC without hu-mapper: the driver has no switch for HU_GCC_WRAPPERS; a copy of run_suite.cmake with "list(APPEND TC_ARGS -DHU_GCC_WRAPPERS=ON)" before "set(ALL_TESTS" (and PROTO set to the checkout when the copy lives elsewhere) runs the suite's checks that way (t21 excluded: its space variant expects hu-mapper).