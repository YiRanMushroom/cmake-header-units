@echo off
rem MSVC + MSBuild: configures, builds (Debug) and runs (ctest) the test projects with a Visual Studio generator.
rem HeaderUnits.cmake does nothing there: MSBuild builds the header units itself.  t04/t09 (expected configure
rem errors on GCC/Clang) are skipped.
rem   run-msvc.bat                                   uses the first cmake.exe on PATH
rem   set CMAKE_EXE=C:\path\cmake.exe              choose another CMake (>= 3.28)
rem   set HU_VS_GENERATOR=Visual Studio 17 2022      choose the generator (default)
rem   set TESTS=t01 t07                              run a subset
setlocal EnableDelayedExpansion
set "HERE=%~dp0"
if not defined CMAKE_EXE for /f "delims=" %%i in ('where cmake.exe') do if not defined CMAKE_EXE set "CMAKE_EXE=%%i"
if not defined HU_VS_GENERATOR set "HU_VS_GENERATOR=Visual Studio 17 2022"
if not defined TESTS set "TESTS=t01_stl t02_thirdparty t03_named_modules t05_rebuild t06_mixed t07_own_headers t08_auto t10_header_imports t11_transitive t12_build_tree"
set "OUT=%HERE%_build\msvc"
if not exist "%OUT%" mkdir "%OUT%"
set "RES=%OUT%\results.txt"
type nul > "%RES%"
for %%t in (%TESTS%) do (
  set "T=%%t"
  for /d %%d in ("%HERE%tests\%%t*") do set "SRC=%%~fd" & set "NAME=%%~nxd"
  set "B=%OUT%\!NAME!"
  if exist "!B!" rmdir /s /q "!B!"
  set "V=PASS"
  "%CMAKE_EXE%" -S "!SRC!" -B "!B!" -G "%HU_VS_GENERATOR%" -A x64 > "!B!.log" 2>&1 || set "V=FAIL(configure)"
  if "!V!"=="PASS" "%CMAKE_EXE%" --build "!B!" --config Debug >> "!B!.log" 2>&1 || set "V=FAIL(build)"
  if "!V!"=="PASS" ( pushd "!B!" & ctest -C Debug --output-on-failure >> "!B!.log" 2>&1 || set "V=FAIL(ctest)" & popd )
  echo msvc^|!NAME!^|!V!>> "%RES%"
  echo !V!  msvc  !NAME!
)
endlocal
