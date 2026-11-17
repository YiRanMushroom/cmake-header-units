#!/bin/sh
# Runs the adversarial scenarios (tests/attack) on Linux for GCC (>= 16) and Clang (>= 22, libstdc++), in parallel.
#   sh tests/attack/run-attack-linux.sh
#   CMAKE_EXE=/path/to/cmake sh tests/attack/run-attack-linux.sh     (default: cmake on PATH; tested 4.5.0)
#   SCEN="a03;a05" ...                                               (subset, prefix match on the variant id)
#   CLANG_CXX=clang++-22 CLANG_FLAGS=--gcc-toolchain=/usr/local      (defaults, matching docker/Dockerfile)
# Results: _build/attack-gcc/results.txt, _build/attack-clang/results.txt (logs/ next to them).
cd "$(dirname "$0")/../.." || exit 1
CMAKE_EXE=${CMAKE_EXE:-$(command -v cmake)}
mkdir -p _build
"$CMAKE_EXE" -DTC=gcc -DCMAKE_EXE="$CMAKE_EXE" "-DSCEN=${SCEN}" -P tests/attack/run_attack.cmake > _build/attack-run-gcc.txt 2>&1 &
"$CMAKE_EXE" -DTC=clang -DCMAKE_EXE="$CMAKE_EXE" "-DSCEN=${SCEN}" \
  "-DCLANG_CXX=${CLANG_CXX:-clang++-22}" "-DCLANG_FLAGS=${CLANG_FLAGS:---gcc-toolchain=/usr/local}" \
  -P tests/attack/run_attack.cmake > _build/attack-run-clang.txt 2>&1 &
wait
cat _build/attack-gcc/results.txt _build/attack-clang/results.txt 2>/dev/null
