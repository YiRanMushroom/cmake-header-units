+++
title = "Header-unit compile options for GCC: -Mno-modules, not -fdeps-format (IDEs run these flags without -M)"
keys = [ "clion", "depfile", "fdeps-format", "gcc", "mno-modules" ]
updated = "2026-11-19 00:22:56"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "-fmodule-only;${mopt};-Mno-modules"
+++
Without either option GCC's -MD depfile gets module-name rules ("<hdr>.c++-module: <cmi>", .PHONY, and on Windows broken ":/..." targets) that Ninja records as never-existing inputs, so the second build is not a no-op. -fdeps-format=p1689r5 also suppresses them but makes a compile without -M fail ("to generate dependencies you must specify either '-M' or '-MM'"); CLion runs every source's FLAGS with -E -dD -v and without -M to read compiler information, and failed for every header unit. -Mno-modules does the same for the depfile and is harmless without -M. Consumer TUs are unaffected: CMake puts its own -fdeps-format in the rule command, not in FLAGS.