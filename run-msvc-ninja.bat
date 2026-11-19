@echo off
rem Runs the test suite with MSVC and the Ninja generator (the module builds the header units).
rem   run-msvc-ninja.bat                  uses the first cmake.exe on PATH
rem   set CMAKE_EXE=C:\path\cmake.exe    choose another CMake (>= 4.2)
rem   set TESTS=t01;t07                  run a subset
rem   set JOBS=8                         tests at a time (default: a quarter of the logical cores)
rem Needs ninja and cmake on PATH, MSVC 19.40 or later (a VS Developer prompt, or vcvars64.bat is located via vswhere),
rem and fmt 10.1.1 + nlohmann_json 3.11.3 sources in ext-src\ (see README).
setlocal
set "HERE=%~dp0"
if defined VCINSTALLDIR goto haveenv
set "PF86=%ProgramFiles(x86)%"
if not defined PF86 set "PF86=C:\Program Files (x86)"
set "VSDIR="
pushd "%PF86%\Microsoft Visual Studio\Installer" 2>nul && (
  for /f "delims=" %%i in ('.\vswhere.exe -latest -products * -property installationPath') do set "VSDIR=%%i"
  popd
)
if not defined VSDIR (echo run-msvc-ninja.bat: Visual Studio not found; open a VS Developer prompt & exit /b 1)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
:haveenv
if not defined CMAKE_EXE for /f "delims=" %%i in ('where cmake.exe') do if not defined CMAKE_EXE set "CMAKE_EXE=%%i"
"%CMAKE_EXE%" -DTC=msvc "-DCMAKE_EXE=%CMAKE_EXE%" -DTAG=local "-DTESTS=%TESTS%" "-DJOBS=%JOBS%" -P "%HERE%tests\run_parallel.cmake"
echo.
echo toolchain^|cmake^|test^|verdict^|time^|evidence
type "%HERE%_build\msvc-local\results.txt"
endlocal
