+++
title = "tests/run_parallel.cmake: suite tests in parallel via CTest (all runner scripts use it)"
keys = [ "ctest", "jobs", "parallel", "results", "run_parallel", "test speed" ]
updated = "2026-11-19 17:52:27"
checked = "2026-11-19"

[[links]]
path = "tests/run_parallel.cmake"
snippet = "execute_process(COMMAND \"${CTEST_EXE}\" --test-dir \"${par}\" -j ${JOBS} --timeout 7200)"

[[items]]
name = "ninja-jobs"
value = "NINJA_JOBS (-D or env) adds -j<n> to each ninja run; run_parallel passes it on. Here (12 threads, 16 GB) 4 Windows suites at once plus Linux in WSL froze the machine: run Windows toolchains one after another with JOBS=2 NINJA_JOBS=6."
path = "tests/run_suite.cmake"
snippet = "list(APPEND NINJA -j ${NINJA_JOBS})"
+++
Each test = one CTest test running run_suite.cmake -DTESTS=<test> -DRESULTS=<root>/par/<test>.txt; ctest -j JOBS (default ncpu/4); results merged into <root>/results.txt in ALL_TESTS order (parsed from run_suite.cmake). Tests only write under <root>/<test>* so they can share a root. Run all toolchains at once too: Windows 4 TCs (separate cmd envs) + Linux containers. Pitfall seen: if(NOT n) reads n as the false constant N.