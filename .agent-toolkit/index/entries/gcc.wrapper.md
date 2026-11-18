+++
title = "GCC header units are compiled from a generated wrapper (#include of the header), so a self-including header works"
kind = "design"
keys = [ "build tree header", "dependency cycle", "depends on itself", "fmt format.h", "self-include", "wrapper" ]
updated = "2026-11-18 23:50:59"
checked = "2026-11-18"

[[links]]
path = "cmake/HeaderUnits/GCC.cmake"
snippet = "function(_hu_gcc_wrapper src_out keys_out hudir p)"
+++
GCC's file mapper translates every #include of a listed path into an import, and exporting and importing use the same key, so a header unit's own mapper could not list the header without GCC also importing it when the header includes itself through another one (fmt's core.h includes "format.h" when header-only; t21_self_include). Then: GCC notes "import ... failed, falling back to include" and its depfile names the CMI as its own input (Ninja: dependency cycle); with the CMI spelled absolute instead, the next build after a change fails with "module ... depends on itself" (the old CMI exists). Linux GCC behaves the same (t21), MinGW only showed it first (t08 with header-only fmt).
Fix: CMake compiles hudir/gcc/w/<md5-16>/<name> containing only #include "<p>"; the header unit's own map lists the wrapper's spellings (abs, real, relative to the build dir as CMake passes build-tree sources, ./relative), not p; consumers' maps keep p's keys. GCC does not check a header unit's name when reading the CMI ("header units can be aliased", module.cc read_config). Side effects: headers in the build tree need no launcher any more (gcc-abs-src.sh removed; t12 passes on MinGW); #pragma GCC system_header in the header now applies. Core records the compiled source per header (_HU_SET_<s>_SRCS; Clang: p after its macro made p the real path).