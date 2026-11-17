@echo off
rem Runs the test suite on Windows with clang++ (GNU-style driver, x86_64-pc-windows-msvc, MSVC STL).
rem   run-win.bat                        uses the first cmake.exe on PATH
rem   set CMAKE_EXE=C:\path\cmake.exe    choose another CMake (>= 4.2; tested 4.4.5 and 4.5.0)
rem   set TESTS=t01;t07                  run a subset
rem Needs clang++ and ninja on PATH, the MSVC environment (a VS Developer prompt, or vcvars64.bat is
rem located via vswhere), and fmt 10.1.1 + nlohmann_json 3.11.3 sources in ext-src\ (see README).
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
if not defined VSDIR (echo run-win.bat: Visual Studio not found; open a VS Developer prompt & exit /b 1)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
:haveenv
if not defined CMAKE_EXE for /f "delims=" %%i in ('where cmake.exe') do if not defined CMAKE_EXE set "CMAKE_EXE=%%i"
"%CMAKE_EXE%" -DTC=win "-DCMAKE_EXE=%CMAKE_EXE%" -DTAG=local "-DTESTS=%TESTS%" -P "%HERE%tests\run_suite.cmake"
echo.
echo toolchain^|cmake^|test^|verdict^|time^|evidence
type "%HERE%_build\win-local\results.txt"
endlocal
