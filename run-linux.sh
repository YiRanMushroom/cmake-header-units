#!/bin/sh
# Runs the test suite on Linux for GCC (>= 16) and Clang (>= 22) with libstdc++ and with libc++, in fresh build dirs:
# the three toolchains at once, and within each the tests in parallel (tests/run_parallel.cmake; JOBS=<n> tests at a time).
#   sh run-linux.sh
#   CMAKE_EXE=/path/to/cmake sh run-linux.sh        (default: cmake on PATH; tested 4.4.5 and 4.5.0)
#   TESTS="t01;t07" sh run-linux.sh                  (subset)
#   CLANG_CXX=clang++-22 CLANG_FLAGS=--gcc-toolchain=/usr/local   (defaults, matching docker/Dockerfile)
#   LIBCXX_FLAGS=-stdlib=libc++                      (default; the libc++ run uses CLANG_CXX, not CLANG_FLAGS)
#   LIBCXX_MODULES_JSON=/usr/lib/llvm-22/lib/libc++.modules.json  (default; CMAKE_CXX_STDLIB_MODULES_JSON, empty: unset)
# The toolchain image used for development is described in docker/ (GCC 16 + Clang 22 + libc++ + fmt/json/Boost).
cd "$(dirname "$0")" || exit 1
CMAKE_EXE=${CMAKE_EXE:-$(command -v cmake)}
mkdir -p _build
"$CMAKE_EXE" -DTC=gcc   -DCMAKE_EXE="$CMAKE_EXE" -DTAG=local "-DTESTS=${TESTS}" "-DJOBS=${JOBS}" -P tests/run_parallel.cmake > _build/run-gcc.txt 2>&1 &
"$CMAKE_EXE" -DTC=clang -DCMAKE_EXE="$CMAKE_EXE" -DTAG=local "-DTESTS=${TESTS}" "-DJOBS=${JOBS}" \
  "-DCLANG_CXX=${CLANG_CXX:-clang++-22}" "-DCLANG_FLAGS=${CLANG_FLAGS:---gcc-toolchain=/usr/local}" \
  -P tests/run_parallel.cmake > _build/run-clang.txt 2>&1 &
"$CMAKE_EXE" -DTC=libcxx -DCMAKE_EXE="$CMAKE_EXE" -DTAG=local "-DTESTS=${TESTS}" "-DJOBS=${JOBS}" \
  "-DCLANG_CXX=${CLANG_CXX:-clang++-22}" "-DLIBCXX_FLAGS=${LIBCXX_FLAGS:--stdlib=libc++}" \
  "-DLIBCXX_MODULES_JSON=${LIBCXX_MODULES_JSON-/usr/lib/llvm-22/lib/libc++.modules.json}" \
  -P tests/run_parallel.cmake > _build/run-libcxx.txt 2>&1 &
wait
echo "toolchain | cmake | test | verdict"
cat _build/gcc-local/results.txt _build/clang-local/results.txt _build/libcxx-local/results.txt 2>/dev/null | cut -d'|' -f1-4
